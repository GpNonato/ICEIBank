import os


OFFSET = 42
NUMERO_AGENCIAS = 3
PORTA_BASE = 4000 + OFFSET
LIMITE_SAQUE = float(os.getenv("LIMITE_SAQUE", "1000"))
LIMITE_TRANSFERENCIA = float(os.getenv("LIMITE_TRANSFERENCIA", "1000"))

AGENCIAS = [
    {"id": 0, "url": f"http://localhost:{PORTA_BASE}"},
    {"id": 1, "url": f"http://localhost:{PORTA_BASE + 1}"},
    {"id": 2, "url": f"http://localhost:{PORTA_BASE + 2}"},
]


def agencia_responsavel(id_conta: int) -> int:
    return id_conta % NUMERO_AGENCIAS


def obter_agencia(id_agencia: int) -> dict | None:
    return next((agencia for agencia in AGENCIAS if agencia["id"] == id_agencia), None)


def formatar_reais(valor: float) -> str:
    formatado = f"{valor:,.2f}"
    return formatado.replace(",", "_").replace(".", ",").replace("_", ".")
