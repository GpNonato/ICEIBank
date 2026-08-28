import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import ExpiredSignatureError, InvalidTokenError


JWT_SECRET = os.getenv("JWT_SECRET", "iceibank-chave-local-sprint1-2026")
JWT_ALGORITMO = "HS256"
JWT_EXPIRACAO_SEGUNDOS = int(os.getenv("JWT_EXPIRACAO_SEGUNDOS", "900"))
USUARIO_PADRAO = os.getenv("ICEIBANK_USUARIO", "gabriel")
SENHA_PADRAO = os.getenv("ICEIBANK_SENHA", "iceibank123")

esquema_bearer = HTTPBearer(auto_error=False)


def autenticar(usuario: str, senha: str) -> bool:
    usuario_valido = secrets.compare_digest(usuario, USUARIO_PADRAO)
    senha_valida = secrets.compare_digest(senha, SENHA_PADRAO)
    return usuario_valido and senha_valida


def gerar_token_usuario(usuario: str) -> str:
    return _gerar_token(usuario, "usuario")


def gerar_token_agencia(id_agencia: int) -> str:
    return _gerar_token(f"agencia-{id_agencia}", "agencia")


def _gerar_token(sujeito: str, tipo: str) -> str:
    agora = datetime.now(timezone.utc)
    dados = {
        "sub": sujeito,
        "tipo": tipo,
        "iat": agora,
        "exp": agora + timedelta(seconds=JWT_EXPIRACAO_SEGUNDOS),
    }
    return jwt.encode(dados, JWT_SECRET, algorithm=JWT_ALGORITMO)


async def validar_token_usuario(
    credenciais: HTTPAuthorizationCredentials | None = Security(esquema_bearer),
) -> dict:
    dados = _validar_token(credenciais)
    if dados.get("tipo") != "usuario":
        raise _erro_401("Token sem permissão de usuário.")
    return dados


async def validar_token_agencia(
    credenciais: HTTPAuthorizationCredentials | None = Security(esquema_bearer),
) -> dict:
    dados = _validar_token(credenciais)
    if dados.get("tipo") != "agencia":
        raise _erro_401("Token sem permissão de agência.")
    return dados


def _validar_token(credenciais: HTTPAuthorizationCredentials | None) -> dict:
    if credenciais is None or credenciais.scheme.lower() != "bearer":
        raise _erro_401("Token não informado.")
    try:
        return jwt.decode(
            credenciais.credentials,
            JWT_SECRET,
            algorithms=[JWT_ALGORITMO],
            options={"require": ["sub", "tipo", "exp"]},
        )
    except ExpiredSignatureError as erro:
        raise _erro_401("Token expirado.") from erro
    except InvalidTokenError as erro:
        raise _erro_401("Token inválido.") from erro


def _erro_401(mensagem: str) -> HTTPException:
    return HTTPException(
        status_code=401,
        detail=mensagem,
        headers={"WWW-Authenticate": "Bearer"},
    )
