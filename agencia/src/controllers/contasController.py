from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse

from ..config import LIMITE_SAQUE, agencia_responsavel, formatar_reais
from ..models import CriarContaEntrada, SincronizacaoEntrada, TransferenciaEntrada, ValorEntrada
from ..services.alertas import verificar_saldo_baixo
from ..services.compararVetores import comparar_vetores
from .transferenciasController import transferir


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
    estado = request.app.state
    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    # O app guarda este vetor e o devolve ao sincronizar uma operação feita offline.
    return {**conta, "vetorAtual": estado.relogio.obter_vetor_atual()}


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
    if dados.valor > LIMITE_SAQUE:
        raise HTTPException(400, f"Limite de saque por operação: R$ {formatar_reais(LIMITE_SAQUE)}.")
    if conta["saldo"] < dados.valor:
        raise HTTPException(400, "Saldo insuficiente.")
    timestamp = estado.relogio.evento_local()
    conta["saldo"] -= dados.valor
    estado.registro.registrar(
        "SAQUE", timestamp,
        {"id": id_conta, "valor": dados.valor, "novoSaldo": conta["saldo"]},
    )
    await verificar_saldo_baixo(estado, conta)
    return conta


async def sincronizar_operacao_pendente(
    id_conta: int, dados: SincronizacaoEntrada, request: Request,
):
    estado = request.app.state
    conta = estado.contas.get(id_conta)
    if conta is None:
        raise HTTPException(404, "Conta não encontrada nesta agência.")

    # Reenvio de uma operação que já foi aplicada (ex.: a resposta se perdeu na
    # rede e o app tentou de novo): devolve o resultado anterior.
    if dados.idOperacao and dados.idOperacao in estado.sincronizacoes_processadas:
        return {**estado.sincronizacoes_processadas[dados.idOperacao], "repetida": True}

    vetor_atual = estado.relogio.obter_vetor_atual()
    if len(dados.vetorConhecido) != len(vetor_atual):
        raise HTTPException(400, f"O vetor conhecido deve ter {len(vetor_atual)} posições.")

    relacao = comparar_vetores(dados.vetorConhecido, vetor_atual)
    if relacao != "IGUAIS":
        # Outras operações aconteceram na agência desde a última leitura do app:
        # não aplica cegamente e devolve o estado atual para o app decidir. A
        # recusa não altera estado, então não é registrada como evento do relógio.
        print(
            f"[Sincronização] conflito na conta {id_conta}: vetor conhecido "
            f"{dados.vetorConhecido} x vetor atual {vetor_atual} ({relacao})",
            flush=True,
        )
        return JSONResponse(
            status_code=409,
            media_type="application/json; charset=utf-8",
            content={
                "erro": "Conflito detectado: o estado da conta mudou desde a última sincronização do app.",
                "relacao": relacao,
                "vetorConhecido": dados.vetorConhecido,
                "vetorAtual": vetor_atual,
                "contaAtual": conta,
            },
        )

    if dados.valor <= 0:
        raise HTTPException(400, "O valor da operação deve ser positivo.")

    tipo = dados.tipo.upper()
    detalhes = {"id": id_conta, "tipo": tipo, "valor": dados.valor, "idOperacao": dados.idOperacao}
    extra = {}
    if tipo == "DEPOSITO":
        timestamp = estado.relogio.evento_local()
        conta["saldo"] += dados.valor
    elif tipo == "SAQUE":
        if dados.valor > LIMITE_SAQUE:
            raise HTTPException(400, f"Limite de saque por operação: R$ {formatar_reais(LIMITE_SAQUE)}.")
        if conta["saldo"] < dados.valor:
            raise HTTPException(400, "Saldo insuficiente.")
        timestamp = estado.relogio.evento_local()
        conta["saldo"] -= dados.valor
    elif tipo == "TRANSFERENCIA":
        if dados.idDestino is None:
            raise HTTPException(400, "Informe a conta de destino da transferência.")
        # A comparação de vetores é a mesma; quando aprovada, a transferência segue
        # o fluxo normal (local ou publicada para a agência de destino).
        extra["transferencia"] = await transferir(
            TransferenciaEntrada(
                idOrigem=id_conta, idDestino=dados.idDestino,
                valor=dados.valor, idOperacao=dados.idOperacao,
            ),
            request,
        )
        detalhes["idDestino"] = dados.idDestino
        timestamp = estado.relogio.evento_local()
    else:
        raise HTTPException(400, "Tipo de operação pendente não suportado.")

    estado.registro.registrar(
        "SINCRONIZACAO_OFFLINE", timestamp, {**detalhes, "novoSaldo": conta["saldo"]},
    )
    if tipo == "SAQUE":
        await verificar_saldo_baixo(estado, conta)

    resposta = {
        **conta, **extra,
        "vetorAtual": estado.relogio.obter_vetor_atual(),
        "idOperacao": dados.idOperacao,
        "repetida": False,
    }
    if dados.idOperacao:
        estado.sincronizacoes_processadas[dados.idOperacao] = resposta
    return resposta
