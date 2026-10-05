import argparse
import asyncio
import json

import aio_pika
from aiormq.exceptions import ChannelNotFoundEntity, ChannelPreconditionFailed

from src.config import NUMERO_AGENCIAS, RABBITMQ_URL


FILAS_AGENCIAS = [f"fila-agencia-{id_agencia}" for id_agencia in range(NUMERO_AGENCIAS)]
FILA_MORTAS = "fila-mensagens-mortas"
FILAS = FILAS_AGENCIAS + ["fila-auditoria", FILA_MORTAS]


async def listar_filas(conexao: aio_pika.abc.AbstractConnection) -> None:
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


async def listar_mortas(conexao: aio_pika.abc.AbstractConnection) -> None:
    canal = await conexao.channel()
    try:
        fila = await canal.declare_queue(FILA_MORTAS, passive=True)
    except ChannelNotFoundEntity:
        print(f"{FILA_MORTAS} ainda não existe.")
        return

    # Lê sem consumir: as mensagens são devolvidas à fila no final.
    lidas = []
    while (mensagem := await fila.get(no_ack=False, fail=False)) is not None:
        lidas.append(mensagem)
        morte = (mensagem.headers.get("x-death") or [{}])[0]
        motivo = morte.get("reason", "?")
        fila_origem = morte.get("queue", "?")
        print(f"[{fila_origem} -> {FILA_MORTAS}] motivo={motivo} routingKey={mensagem.routing_key}")
        print(f"    {json.dumps(json.loads(mensagem.body), ensure_ascii=False)}")
    if not lidas:
        print(f"{FILA_MORTAS} está vazia.")
    for mensagem in lidas:
        await mensagem.nack(requeue=True)


async def recriar_filas_agencias(conexao: aio_pika.abc.AbstractConnection) -> None:
    # Necessário ao migrar filas criadas antes da dead-letter queue: o RabbitMQ não
    # permite alterar os argumentos de uma fila já existente.
    for nome in FILAS_AGENCIAS:
        canal = await conexao.channel()
        try:
            await canal.queue_delete(nome, if_empty=True)
            print(f"{nome} apagada; será recriada quando a agência iniciar.")
        except ChannelPreconditionFailed:
            print(f"{nome} tem mensagens pendentes e não foi apagada.")


async def main() -> None:
    parser = argparse.ArgumentParser(description="Inspeciona as filas do ICEIBank no RabbitMQ.")
    parser.add_argument("--mortas", action="store_true", help="lista as mensagens da fila de mensagens mortas")
    parser.add_argument("--recriar", action="store_true", help="apaga as filas vazias das agências")
    argumentos = parser.parse_args()

    if not RABBITMQ_URL:
        print("Defina RABBITMQ_URL (variável de ambiente ou arquivo agencia/.env).")
        return

    conexao = await aio_pika.connect(RABBITMQ_URL)
    async with conexao:
        if argumentos.recriar:
            await recriar_filas_agencias(conexao)
        elif argumentos.mortas:
            await listar_mortas(conexao)
        else:
            await listar_filas(conexao)


if __name__ == "__main__":
    asyncio.run(main())
