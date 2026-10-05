import asyncio
import json
import sys
from collections.abc import Awaitable, Callable
from uuid import uuid4

import aio_pika

from ..config import RABBITMQ_URL


EXCHANGE = "iceibank.eventos"
EXCHANGE_MORTAS = "iceibank.mortas"
FILA_MORTAS = "fila-mensagens-mortas"
MAX_TENTATIVAS = 3
ESPERA_ENTRE_TENTATIVAS = 1.0

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
_tentativas: dict[str, int] = {}


class ErroProcessamento(Exception):
    """Falha ao aplicar uma mensagem; ela volta para a fila até esgotar as tentativas."""


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
            message_id=str(uuid4()),
        ),
        routing_key=routing_key,
    )


async def declarar_fila_mortas() -> None:
    await obter_exchange()
    exchange_mortas = await _canal.declare_exchange(
        EXCHANGE_MORTAS, aio_pika.ExchangeType.TOPIC, durable=True,
    )
    fila = await _canal.declare_queue(FILA_MORTAS, durable=True)
    await fila.bind(exchange_mortas, "#")


async def consumir(
    nome_fila: str,
    chaves: list[str],
    ao_receber: Callable[[str, dict], Awaitable[None]],
    ao_desistir: Callable[[str, dict | None, Exception], Awaitable[None]] | None = None,
) -> None:
    exchange = await obter_exchange()
    argumentos = None
    if ao_desistir is not None:
        # Mensagens rejeitadas sem requeue são reencaminhadas pelo RabbitMQ para a
        # exchange de mensagens mortas, mantendo a routing key original.
        await declarar_fila_mortas()
        argumentos = {"x-dead-letter-exchange": EXCHANGE_MORTAS}
    fila = await _canal.declare_queue(nome_fila, durable=True, arguments=argumentos)
    for chave in chaves:
        await fila.bind(exchange, chave)

    async def processar(mensagem: aio_pika.abc.AbstractIncomingMessage) -> None:
        if ao_desistir is None:
            async with mensagem.process():
                await ao_receber(mensagem.routing_key, json.loads(mensagem.body))
            return

        id_mensagem = mensagem.message_id or str(mensagem.delivery_tag)
        conteudo = None
        try:
            conteudo = json.loads(mensagem.body)
            await ao_receber(mensagem.routing_key, conteudo)
        except Exception as erro:
            tentativa = _tentativas.get(id_mensagem, 0) + 1
            if tentativa < MAX_TENTATIVAS:
                _tentativas[id_mensagem] = tentativa
                print(
                    f"[Mensageria] falha em {mensagem.routing_key} ({erro}) - "
                    f"tentativa {tentativa}/{MAX_TENTATIVAS}, devolvendo à fila",
                    flush=True,
                )
                await asyncio.sleep(ESPERA_ENTRE_TENTATIVAS)
                await mensagem.nack(requeue=True)
                return
            _tentativas.pop(id_mensagem, None)
            print(
                f"[Mensageria] falha em {mensagem.routing_key} ({erro}) - "
                f"tentativa {tentativa}/{MAX_TENTATIVAS}, enviando para {FILA_MORTAS}",
                flush=True,
            )
            try:
                await ao_desistir(mensagem.routing_key, conteudo, erro)
            finally:
                await mensagem.reject(requeue=False)
            return
        _tentativas.pop(id_mensagem, None)
        await mensagem.ack()

    await fila.consume(processar)


async def assinar(
    id_agencia: int,
    tratadores: dict[str, Callable[[dict], Awaitable[None]]],
    ao_desistir: Callable[[str, dict | None, Exception], Awaitable[None]],
) -> None:
    # Uma única fila por agência, ligada a uma routing key por tipo de mensagem
    # (ex.: agencia.1.creditar e agencia.1.confirmacao).
    async def despachar(routing_key: str, conteudo: dict) -> None:
        await tratadores[routing_key.rsplit(".", 1)[1]](conteudo)

    await consumir(
        f"fila-agencia-{id_agencia}",
        [f"agencia.{id_agencia}.{tipo}" for tipo in tratadores],
        despachar,
        ao_desistir,
    )


async def fechar() -> None:
    global _conexao, _canal, _exchange
    if _conexao is not None:
        await _conexao.close()
    _conexao = _canal = _exchange = None
