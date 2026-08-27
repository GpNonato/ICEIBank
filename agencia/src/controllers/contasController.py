from fastapi import HTTPException, Request

from ..config import agencia_responsavel
from ..models import CriarContaEntrada, ValorEntrada


async def criar_conta(dados: CriarContaEntrada, request: Request):
    estado = request.app.state
    if agencia_responsavel(dados.id) != estado.id_agencia:
        raise HTTPException(400, f"Conta {dados.id} não pertence a esta agência.")
    if dados.id in estado.contas:
        raise HTTPException(409, "Conta já existe.")

    timestamp = estado.relogio.evento_local()
    conta = {"id": dados.id, "nomeAluno": dados.nomeAluno, "saldo": dados.saldoInicial}
    estado.contas[dados.id] = conta
    estado.registro.registrar(
        "CRIAR_CONTA",
        timestamp,
        {"id": dados.id, "nomeAluno": dados.nomeAluno, "saldoInicial": dados.saldoInicial},
    )
    return conta


async def consultar_saldo(id_conta: int, request: Request):
    conta = request.app.state.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    return conta


async def depositar(id_conta: int, dados: ValorEntrada, request: Request):
    estado = request.app.state
    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    timestamp = estado.relogio.evento_local()
    conta["saldo"] += dados.valor
    estado.registro.registrar(
        "DEPOSITO", timestamp,
        {"id": id_conta, "valor": dados.valor, "novoSaldo": conta["saldo"]},
    )
    return conta


async def sacar(id_conta: int, dados: ValorEntrada, request: Request):
    estado = request.app.state
    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    if conta["saldo"] < dados.valor:
        raise HTTPException(400, "Saldo insuficiente.")
    timestamp = estado.relogio.evento_local()
    conta["saldo"] -= dados.valor
    estado.registro.registrar(
        "SAQUE", timestamp,
        {"id": id_conta, "valor": dados.valor, "novoSaldo": conta["saldo"]},
    )
    return conta
