from pydantic import BaseModel


class CriarContaEntrada(BaseModel):
    id: int
    nomeAluno: str
    saldoInicial: float = 0


class ValorEntrada(BaseModel):
    valor: float


class TransferenciaEntrada(BaseModel):
    idOrigem: int
    idDestino: int
    valor: float
    idOperacao: str | None = None


class CreditoRemotoEntrada(BaseModel):
    valor: float
    timestampLamport: int
    origemAgencia: int
    idOperacao: str


class LoginEntrada(BaseModel):
    usuario: str
    senha: str
