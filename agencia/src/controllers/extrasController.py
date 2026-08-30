import httpx
from fastapi import HTTPException, Request

from ..config import AGENCIAS, LIMITE_SAQUE, LIMITE_TRANSFERENCIA, agencia_responsavel
from ..services.authService import gerar_token_agencia


async def historico_conta(id_conta: int, request: Request):
    estado = request.app.state
    if agencia_responsavel(id_conta) != estado.id_agencia:
        raise HTTPException(400, f"Conta {id_conta} não pertence a esta agência.")
    if id_conta not in estado.contas:
        raise HTTPException(404, "Conta não encontrada nesta agência.")
    return {
        "idConta": id_conta,
        "agencia": estado.id_agencia,
        "eventos": estado.registro.listar_por_conta(id_conta),
    }


async def consultar_limites():
    return {
        "limiteSaque": LIMITE_SAQUE,
        "limiteTransferencia": LIMITE_TRANSFERENCIA,
    }


async def consultar_status(request: Request):
    estado = request.app.state
    return {
        "agencia": estado.id_agencia,
        "url": AGENCIAS[estado.id_agencia]["url"],
        "status": "disponível",
        "relogioLamport": estado.relogio.valor_atual(),
        "quantidadeContas": len(estado.contas),
    }


async def listar_contas_internas(nomeAluno: str, timestampLamport: int, request: Request):
    estado = request.app.state
    estado.relogio.ao_receber(timestampLamport)
    contas = [
        conta for conta in estado.contas.values()
        if conta["nomeAluno"].casefold() == nomeAluno.casefold()
    ]
    return {
        "contas": contas,
        "timestampLamport": estado.relogio.ao_enviar(),
    }


async def extrato_consolidado(nome_aluno: str, request: Request):
    estado = request.app.state
    contas = []
    token_agencia = gerar_token_agencia(estado.id_agencia)

    for agencia in AGENCIAS:
        if agencia["id"] == estado.id_agencia:
            contas.extend(
                conta for conta in estado.contas.values()
                if conta["nomeAluno"].casefold() == nome_aluno.casefold()
            )
            continue

        timestamp_envio = estado.relogio.ao_enviar()
        try:
            async with httpx.AsyncClient(trust_env=False) as cliente:
                resposta = await cliente.get(
                    f"{agencia['url']}/interno/contas",
                    headers={"Authorization": f"Bearer {token_agencia}"},
                    params={"nomeAluno": nome_aluno, "timestampLamport": timestamp_envio},
                )
                resposta.raise_for_status()
            dados = resposta.json()
            estado.relogio.ao_receber(dados["timestampLamport"])
            contas.extend(dados["contas"])
        except httpx.HTTPError as erro:
            raise HTTPException(
                502,
                f"Não foi possível consultar a agência {agencia['id']}.",
            ) from erro

    contas_ordenadas = sorted(contas, key=lambda conta: conta["id"])
    return {
        "nomeAluno": nome_aluno,
        "contas": contas_ordenadas,
        "saldoTotal": sum(conta["saldo"] for conta in contas_ordenadas),
    }
