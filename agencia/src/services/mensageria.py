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


async def consumir(
    nome_fila: str,
    chaves: list[str],
    ao_receber: Callable[[str, dict], Awaitable[None]],
) -> None:
    exchange = await obter_exchange()
    fila = await _canal.declare_queue(nome_fila, durable=True)
    for chave in chaves:
        await fila.bind(exchange, chave)

    async def processar(mensagem: aio_pika.abc.AbstractIncomingMessage) -> None:
        async with mensagem.process():
            await ao_receber(mensagem.routing_key, json.loads(mensagem.body))

    await fila.consume(processar)


async def assinar(
    id_agencia: int,
    tratadores: dict[str, Callable[[dict], Awaitable[None]]],
) -> None:
    # Uma única fila por agência, ligada a uma routing key por tipo de mensagem
    # (ex.: agencia.1.creditar e agencia.1.confirmacao).
    async def despachar(routing_key: str, conteudo: dict) -> None:
        await tratadores[routing_key.rsplit(".", 1)[1]](conteudo)

    await consumir(
        f"fila-agencia-{id_agencia}",
        [f"agencia.{id_agencia}.{tipo}" for tipo in tratadores],
        despachar,
    )


async def fechar() -> None:
    global _conexao, _canal, _exchange
    if _conexao is not None:
        await _conexao.close()
    _conexao = _canal = _exchange = None
