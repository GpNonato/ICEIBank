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


class LoginEntrada(BaseModel):
    usuario: str
    senha: str


class SincronizacaoEntrada(BaseModel):
    tipo: str
    valor: float
    vetorConhecido: list[int]
    idDestino: int | None = None
    idOperacao: str | None = None


class EleicaoEntrada(BaseModel):
    origemId: int
    vetorEnvio: list[int]


class CoordenadorEntrada(BaseModel):
    liderId: int
    vetorEnvio: list[int]
