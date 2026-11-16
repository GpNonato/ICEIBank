from fastapi import Request

from ..models import CoordenadorEntrada, EleicaoEntrada


async def receber_eleicao(dados: EleicaoEntrada, request: Request):
    request.app.state.bully.receber_eleicao(dados.origemId, dados.vetorEnvio)
    return {"ok": True}


async def receber_coordenador(dados: CoordenadorEntrada, request: Request):
    request.app.state.bully.receber_coordenador(dados.liderId, dados.vetorEnvio)
    return {"ok": True}


async def consultar_lider(request: Request):
    estado = request.app.state
    return {"idAgencia": estado.id_agencia, "liderAtual": estado.bully.obter_lider_atual()}


async def consultar_historico(request: Request):
    estado = request.app.state
    return {"idAgencia": estado.id_agencia, "historico": estado.bully.historico()}
