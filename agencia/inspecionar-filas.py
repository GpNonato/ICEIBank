import asyncio

import aio_pika
from aiormq.exceptions import ChannelNotFoundEntity

from src.config import NUMERO_AGENCIAS, RABBITMQ_URL


FILAS = [f"fila-agencia-{id_agencia}" for id_agencia in range(NUMERO_AGENCIAS)] + ["fila-auditoria"]


async def main() -> None:
    if not RABBITMQ_URL:
        print("Defina RABBITMQ_URL (variável de ambiente ou arquivo agencia/.env).")
        return

    conexao = await aio_pika.connect(RABBITMQ_URL)
    async with conexao:
        print(f"{'fila':<26}{'mensagens':>10}{'consumidores':>14}")
        for nome in FILAS:
            canal = await conexao.channel()
            try:
                fila = await canal.declare_queue(nome, passive=True)
            except ChannelNotFoundEntity:
                print(f"{nome:<26}{'(não existe)':>24}")
                continue
            resultado = fila.declaration_result
            print(f"{nome:<26}{resultado.message_count:>10}{resultado.consumer_count:>14}")


if __name__ == "__main__":
    asyncio.run(main())
