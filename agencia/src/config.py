OFFSET = 42
NUMERO_AGENCIAS = 3
PORTA_BASE = 4000 + OFFSET

AGENCIAS = [
    {"id": 0, "url": f"http://localhost:{PORTA_BASE}"},
    {"id": 1, "url": f"http://localhost:{PORTA_BASE + 1}"},
    {"id": 2, "url": f"http://localhost:{PORTA_BASE + 2}"},
]


def agencia_responsavel(id_conta: int) -> int:
    return id_conta % NUMERO_AGENCIAS


def obter_agencia(id_agencia: int) -> dict | None:
    return next((agencia for agencia in AGENCIAS if agencia["id"] == id_agencia), None)
