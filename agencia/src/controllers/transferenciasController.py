import httpx
from fastapi import HTTPException, Request

from ..config import agencia_responsavel, obter_agencia
from ..models import CreditoRemotoEntrada, TransferenciaEntrada


async def transferir(dados: TransferenciaEntrada, request: Request):
    estado = request.app.state
    conta_origem = estado.contas.get(dados.idOrigem)
    if conta_origem is None:
        raise HTTPException(404, "Conta de origem não encontrada nesta agência.")
    if conta_origem["saldo"] < dados.valor:
        raise HTTPException(400, "Saldo insuficiente.")

    agencia_destino = agencia_responsavel(dados.idDestino)
    timestamp_debito = estado.relogio.evento_local()
    conta_origem["saldo"] -= dados.valor
    detalhes = {"idOrigem": dados.idOrigem, "idDestino": dados.idDestino, "valor": dados.valor}
    estado.registro.registrar("TRANSFERENCIA_DEBITO", timestamp_debito, detalhes)

    if agencia_destino == estado.id_agencia:
        conta_destino = estado.contas.get(dados.idDestino)
        if conta_destino is None:
            conta_origem["saldo"] += dados.valor
            raise HTTPException(404, "Conta de destino não encontrada.")
        timestamp_credito = estado.relogio.evento_local()
        conta_destino["saldo"] += dados.valor
        estado.registro.registrar("TRANSFERENCIA_CREDITO", timestamp_credito, detalhes)
        return {"mensagem": "Transferência concluída (mesma agência)."}

    timestamp_envio = estado.relogio.ao_enviar()
    destino = obter_agencia(agencia_destino)
    try:
        async with httpx.AsyncClient(trust_env=False) as cliente:
            resposta = await cliente.post(
                f"{destino['url']}/contas/{dados.idDestino}/creditar-remoto",
                json={
                    "valor": dados.valor,
                    "timestampLamport": timestamp_envio,
                    "origemAgencia": estado.id_agencia,
                },
            )
            resposta.raise_for_status()
        return {"mensagem": "Transferência concluída (entre agências)."}
    except httpx.HTTPError as erro:
        estado.registro.registrar(
            "TRANSFERENCIA_FALHOU",
            estado.relogio.evento_local(),
            {**detalhes, "erro": str(erro)},
        )
        raise HTTPException(
            502,
            "Falha ao contatar agência de destino. Débito já aplicado - "
            "inconsistência conhecida (ver Sprint 4).",
        ) from erro


async def creditar_remoto(id_conta: int, dados: CreditoRemotoEntrada, request: Request):
    estado = request.app.state
    timestamp = estado.relogio.ao_receber(dados.timestampLamport)
    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    conta["saldo"] += dados.valor
    estado.registro.registrar(
        "TRANSFERENCIA_CREDITO_REMOTO",
        timestamp,
        {"idConta": id_conta, "valor": dados.valor, "origemAgencia": dados.origemAgencia},
    )
    return {"mensagem": "Crédito remoto aplicado.", "saldoAtual": conta["saldo"]}
