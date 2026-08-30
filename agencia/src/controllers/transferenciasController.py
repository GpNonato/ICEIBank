from uuid import uuid4

import httpx
from fastapi import HTTPException, Request

from ..config import LIMITE_TRANSFERENCIA, agencia_responsavel, formatar_reais, obter_agencia
from ..models import CreditoRemotoEntrada, TransferenciaEntrada
from ..services.authService import gerar_token_agencia


def resultado_anterior(estado, id_operacao: str):
    registro = estado.transferencias_processadas.get(id_operacao)
    if registro is None:
        return None
    if registro["status"] == "concluida":
        return {**registro["resposta"], "repetida": True}
    if registro["status"] == "falhou":
        raise HTTPException(502, registro["mensagem"])
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
        resposta = {
            "mensagem": "Transferência concluída (mesma agência).",
            "idOperacao": id_operacao,
            "repetida": False,
        }
        estado.transferencias_processadas[id_operacao] = {
            "status": "concluida",
            "resposta": resposta,
        }
        return resposta

    timestamp_envio = estado.relogio.ao_enviar()
    destino = obter_agencia(agencia_destino)
    token_agencia = gerar_token_agencia(estado.id_agencia)
    try:
        async with httpx.AsyncClient(trust_env=False) as cliente:
            resposta_remota = await cliente.post(
                f"{destino['url']}/contas/{dados.idDestino}/creditar-remoto",
                headers={"Authorization": f"Bearer {token_agencia}"},
                json={
                    "valor": dados.valor,
                    "timestampLamport": timestamp_envio,
                    "origemAgencia": estado.id_agencia,
                    "idOperacao": id_operacao,
                },
            )
            resposta_remota.raise_for_status()
        resposta = {
            "mensagem": "Transferência concluída (entre agências).",
            "idOperacao": id_operacao,
            "repetida": False,
        }
        estado.transferencias_processadas[id_operacao] = {
            "status": "concluida",
            "resposta": resposta,
        }
        return resposta
    except httpx.HTTPError as erro:
        mensagem = (
            "Falha ao contatar agência de destino. Débito já aplicado - "
            "inconsistência conhecida (ver Sprint 4)."
        )
        estado.transferencias_processadas[id_operacao] = {
            "status": "falhou",
            "mensagem": mensagem,
        }
        estado.registro.registrar(
            "TRANSFERENCIA_FALHOU",
            estado.relogio.evento_local(),
            {**detalhes, "erro": str(erro)},
        )
        raise HTTPException(502, mensagem) from erro


async def creditar_remoto(id_conta: int, dados: CreditoRemotoEntrada, request: Request):
    estado = request.app.state
    timestamp = estado.relogio.ao_receber(dados.timestampLamport)
    anterior = estado.creditos_processados.get(dados.idOperacao)
    if anterior is not None:
        return {**anterior, "repetida": True}

    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    conta["saldo"] += dados.valor
    estado.registro.registrar(
        "TRANSFERENCIA_CREDITO_REMOTO",
        timestamp,
        {
            "idConta": id_conta,
            "valor": dados.valor,
            "origemAgencia": dados.origemAgencia,
            "idOperacao": dados.idOperacao,
        },
    )
    resposta = {
        "mensagem": "Crédito remoto aplicado.",
        "saldoAtual": conta["saldo"],
        "idOperacao": dados.idOperacao,
        "repetida": False,
    }
    estado.creditos_processados[dados.idOperacao] = resposta
    return resposta
