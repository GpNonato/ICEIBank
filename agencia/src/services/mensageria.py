import json
import sys
from collections.abc import Awaitable, Callable

import aio_pika

from ..config import RABBITMQ_URL


EXCHANGE = "iceibank.eventos"

if not RABBITMQ_URL:
    print(
        "Defina RABBITMQ_URL (variável de ambiente ou arquivo agencia/.env) com a "
        "URL AMQP da sua instância CloudAMQP antes de iniciar.",
        file=sys.stderr,
    )
    sys.exit(1)

_conexao: aio_pika.abc.AbstractRobustConnection | None = None
_canal: aio_pika.abc.AbstractChannel | None = None
_exchange: aio_pika.abc.AbstractExchange | None = None


async def obter_exchange() -> aio_pika.abc.AbstractExchange:
    global _conexao, _canal, _exchange
    if _exchange is not None:
        return _exchange
    _conexao = await aio_pika.connect_robust(RABBITMQ_URL)
    _canal = await _conexao.channel()
    await _canal.set_qos(prefetch_count=1)
    _exchange = await _canal.declare_exchange(
        EXCHANGE, aio_pika.ExchangeType.TOPIC, durable=True,
    )
    return _exchange


async def publicar(routing_key: str, mensagem: dict) -> None:
    exchange = await obter_exchange()
    await exchange.publish(
        aio_pika.Message(
            json.dumps(mensagem, ensure_ascii=False).encode("utf-8"),
            content_type="application/json",
            delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
        ),
        routing_key=routing_key,
    )


async def assinar(
    id_agencia: int,
    ao_receber_mensagem: Callable[[dict], Awaitable[None]],
) -> None:
    exchange = await obter_exchange()
    fila = await _canal.declare_queue(f"fila-agencia-{id_agencia}", durable=True)
    await fila.bind(exchange, f"agencia.{id_agencia}.creditar")

    async def consumir(mensagem: aio_pika.abc.AbstractIncomingMessage) -> None:
        async with mensagem.process():
            await ao_receber_mensagem(json.loads(mensagem.body))

    await fila.consume(consumir)


async def fechar() -> None:
    global _conexao, _canal, _exchange
    if _conexao is not None:
        await _conexao.close()
    _conexao = _canal = _exchange = None
