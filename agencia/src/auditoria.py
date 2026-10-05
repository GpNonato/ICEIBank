import asyncio
import json
from datetime import datetime, timezone
from pathlib import Path

from .services import mensageria


FILA = "fila-auditoria"
ARQUIVO = Path(__file__).resolve().parents[1] / "data" / "auditoria" / "auditoria-central.jsonl"


async def registrar(routing_key: str, mensagem: dict) -> None:
    registro = {
        "routingKey": routing_key,
        "horaRecebimento": datetime.now(timezone.utc).isoformat(),
        "mensagem": mensagem,
    }
    with ARQUIVO.open("a", encoding="utf-8") as arquivo:
        arquivo.write(json.dumps(registro, ensure_ascii=False) + "\n")
    marcador = "[Auditoria][ALERTA]" if ".alerta." in routing_key else "[Auditoria]"
    print(f"{marcador} {routing_key} {json.dumps(mensagem, ensure_ascii=False)}", flush=True)


async def main() -> None:
    ARQUIVO.parent.mkdir(parents=True, exist_ok=True)
    # A routing key "#" casa com qualquer chave: a fila recebe uma cópia de toda
    # mensagem publicada na exchange, de todas as agências, sem alterar as filas delas.
    await mensageria.consumir(FILA, ["#"], registrar)
    print(f"[Auditoria] consumindo {FILA} (routing key #) -> {ARQUIVO.name}", flush=True)
    try:
        await asyncio.Future()
    finally:
        await mensageria.fechar()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
