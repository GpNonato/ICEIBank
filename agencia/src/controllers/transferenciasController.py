from uuid import uuid4

from fastapi import HTTPException, Request

from ..config import LIMITE_TRANSFERENCIA, agencia_responsavel, formatar_reais
from ..models import TransferenciaEntrada
from ..services import mensageria
from ..services.alertas import verificar_saldo_baixo


def resultado_anterior(estado, id_operacao: str):
    registro = estado.transferencias_processadas.get(id_operacao)
    if registro is None:
        return None
    if registro["status"] == "concluida":
        return {**registro["resposta"], "repetida": True}
    raise HTTPException(409, "Transferência com este identificador está em processamento.")


async def transferir(dados: TransferenciaEntrada, request: Request):
    estado = request.app.state
    id_operacao = dados.idOperacao or str(uuid4())
    anterior = resultado_anterior(estado, id_operacao)
    if anterior is not None:
        return anterior

    conta_origem = estado.contas.get(dados.idOrigem)
    if conta_origem is None:
        raise HTTPException(404, "Conta de origem não encontrada nesta agência.")
    if dados.valor <= 0:
        raise HTTPException(400, "O valor da transferência deve ser positivo.")
    if dados.valor > LIMITE_TRANSFERENCIA:
        raise HTTPException(
            400,
            f"Limite de transferência por operação: R$ {formatar_reais(LIMITE_TRANSFERENCIA)}.",
        )
    if conta_origem["saldo"] < dados.valor:
        raise HTTPException(400, "Saldo insuficiente.")

    agencia_destino = agencia_responsavel(dados.idDestino)
    estado.transferencias_processadas[id_operacao] = {"status": "processando"}
    timestamp_debito = estado.relogio.evento_local()
    conta_origem["saldo"] -= dados.valor
    detalhes = {
        "idOrigem": dados.idOrigem,
        "idDestino": dados.idDestino,
        "valor": dados.valor,
        "idOperacao": id_operacao,
    }
    estado.registro.registrar("TRANSFERENCIA_DEBITO", timestamp_debito, detalhes)

    if agencia_destino == estado.id_agencia:
        conta_destino = estado.contas.get(dados.idDestino)
        if conta_destino is None:
            conta_origem["saldo"] += dados.valor
            estado.transferencias_processadas.pop(id_operacao, None)
            raise HTTPException(404, "Conta de destino não encontrada.")
        timestamp_credito = estado.relogio.evento_local()
        conta_destino["saldo"] += dados.valor
        estado.registro.registrar("TRANSFERENCIA_CREDITO", timestamp_credito, detalhes)
        await verificar_saldo_baixo(estado, conta_origem)
        return concluir(
            estado, id_operacao, "Transferência concluída (mesma agência).", "concluida", detalhes,
        )

    # Em vez de chamar a outra agência por REST (Sprint 1), a agência publica um
    # evento na exchange. A agência de destino consome quando estiver disponível;
    # se estiver fora do ar, a mensagem fica retida na fila durável.
    timestamp_envio = estado.relogio.ao_enviar()
    try:
        await mensageria.publicar(
            f"agencia.{agencia_destino}.creditar",
            {
                "idConta": dados.idDestino,
                "idOrigem": dados.idOrigem,
                "valor": dados.valor,
                "vetorEnvio": timestamp_envio,
                "origemAgencia": estado.id_agencia,
                "idOperacao": id_operacao,
            },
        )
    except Exception as erro:
        conta_origem["saldo"] += dados.valor
        estado.transferencias_processadas.pop(id_operacao, None)
        estado.registro.registrar(
            "TRANSFERENCIA_FALHOU",
            estado.relogio.evento_local(),
            {**detalhes, "erro": "falha ao publicar no RabbitMQ; débito estornado"},
        )
        raise HTTPException(503, "Não foi possível publicar a transferência. Débito estornado.") from erro

    estado.registro.registrar(
        "TRANSFERENCIA_PUBLICADA",
        timestamp_envio,
        {**detalhes, "routingKey": f"agencia.{agencia_destino}.creditar"},
    )
    await verificar_saldo_baixo(estado, conta_origem)
    return concluir(
        estado,
        id_operacao,
        "Transferência publicada para a agência de destino (entrega assíncrona).",
        "aguardando confirmação",
        detalhes,
    )


def concluir(estado, id_operacao: str, mensagem: str, situacao: str, detalhes: dict) -> dict:
    resposta = {"mensagem": mensagem, "idOperacao": id_operacao, "repetida": False}
    estado.transferencias_processadas[id_operacao] = {
        "status": "concluida",
        "resposta": resposta,
        "situacao": situacao,
        "detalhes": detalhes,
    }
    return resposta


async def consultar_transferencia(id_operacao: str, request: Request):
    registro = request.app.state.transferencias_processadas.get(id_operacao)
    if registro is None or registro["status"] != "concluida":
        raise HTTPException(404, "Transferência não encontrada nesta agência.")
    return {
        **registro["detalhes"],
        "situacao": registro["situacao"],
        **({"motivo": registro["motivo"]} if "motivo" in registro else {}),
    }


async def processar_credito_remoto(estado, mensagem: dict) -> None:
    timestamp = estado.relogio.ao_receber(mensagem["vetorEnvio"])
    id_operacao = mensagem["idOperacao"]
    detalhes = {
        "idConta": mensagem["idConta"],
        "valor": mensagem["valor"],
        "origemAgencia": mensagem["origemAgencia"],
        "idOperacao": id_operacao,
    }
    if id_operacao in estado.creditos_processados:
        estado.registro.registrar("CREDITO_REMOTO_REPETIDO", timestamp, detalhes)
        return

    conta = estado.contas.get(mensagem["idConta"])
    if conta is None:
        estado.registro.registrar(
            "CREDITO_REMOTO_FALHOU",
            timestamp,
            {**detalhes, "motivo": "conta não encontrada"},
        )
        await publicar_confirmacao(estado, mensagem, "falhou", "conta não encontrada")
        return

    conta["saldo"] += mensagem["valor"]
    estado.creditos_processados[id_operacao] = timestamp
    estado.registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", timestamp, detalhes)
    await publicar_confirmacao(estado, mensagem, "creditado")


async def publicar_confirmacao(estado, mensagem: dict, status: str, motivo: str | None = None) -> None:
    chave = f"agencia.{mensagem['origemAgencia']}.confirmacao"
    timestamp = estado.relogio.ao_enviar()
    confirmacao = {
        "idOperacao": mensagem["idOperacao"],
        "idConta": mensagem["idConta"],
        "valor": mensagem["valor"],
        "status": status,
        "agenciaDestino": estado.id_agencia,
        "vetorEnvio": timestamp,
        **({"motivo": motivo} if motivo else {}),
    }
    detalhes = {
        "idConta": mensagem["idConta"],
        "idOperacao": mensagem["idOperacao"],
        "status": status,
        "routingKey": chave,
    }
    try:
        await mensageria.publicar(chave, confirmacao)
    except Exception as erro:
        # O crédito já foi tratado; a falha da confirmação não deve rejeitar a mensagem.
        estado.registro.registrar(
            "CONFIRMACAO_FALHOU", timestamp, {**detalhes, "erro": type(erro).__name__},
        )
        return
    estado.registro.registrar("CONFIRMACAO_PUBLICADA", timestamp, detalhes)


async def processar_confirmacao(estado, mensagem: dict) -> None:
    timestamp = estado.relogio.ao_receber(mensagem["vetorEnvio"])
    registro = estado.transferencias_processadas.get(mensagem["idOperacao"])
    detalhes = {
        **(registro["detalhes"] if registro else {"idDestino": mensagem["idConta"]}),
        "idOperacao": mensagem["idOperacao"],
        "agenciaDestino": mensagem["agenciaDestino"],
    }
    if mensagem["status"] == "creditado":
        if registro:
            registro["situacao"] = "creditada no destino"
        estado.registro.registrar("CONFIRMACAO_CREDITO", timestamp, detalhes)
        return

    if registro:
        registro["situacao"] = "crédito não aplicado no destino"
        registro["motivo"] = mensagem.get("motivo")
    estado.registro.registrar(
        "CREDITO_NAO_CONFIRMADO", timestamp, {**detalhes, "motivo": mensagem.get("motivo")},
    )
