from fastapi import HTTPException

from ..models import LoginEntrada
from ..services import authService


async def login(dados: LoginEntrada):
    if not authService.autenticar(dados.usuario, dados.senha):
        raise HTTPException(
            status_code=401,
            detail="Usuário ou senha inválidos.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authService.gerar_token_usuario(dados.usuario)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": authService.JWT_EXPIRACAO_SEGUNDOS,
    }
