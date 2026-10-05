from ..config import LIMITE_SALDO_BAIXO
from . import mensageria


async def verificar_saldo_baixo(estado, conta: dict) -> None:
    if conta["saldo"] >= LIMITE_SALDO_BAIXO:
        return

    # Tópico separado do crédito: só quem assina "*.*.alerta.#" (ou "#") recebe o alerta.
    chave = f"agencia.{estado.id_agencia}.alerta.saldo-baixo"
    timestamp = estado.relogio.ao_enviar()
    detalhes = {"id": conta["id"], "saldo": conta["saldo"], "limite": LIMITE_SALDO_BAIXO}
    try:
        await mensageria.publicar(
            chave,
            {**detalhes, "agencia": estado.id_agencia, "vetorEnvio": timestamp},
        )
    except Exception as erro:
        estado.registro.registrar(
            "ALERTA_SALDO_BAIXO_FALHOU", timestamp, {**detalhes, "erro": type(erro).__name__},
        )
        return
    estado.registro.registrar("ALERTA_SALDO_BAIXO", timestamp, {**detalhes, "routingKey": chave})
