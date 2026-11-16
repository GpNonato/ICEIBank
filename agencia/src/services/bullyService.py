import asyncio
from collections import deque
from datetime import datetime, timezone
from threading import Lock

import httpx

from ..config import AGENCIAS, obter_agencia


TIMEOUT_SEGUNDOS = 1.0
INTERVALO_HEARTBEAT_SEGUNDOS = 3.0


class ServicoBully:
    """Eleição de líder entre as agências pelo algoritmo de Bully.

    Vence sempre a agência de maior ID entre as que estão ativas. As chamadas
    entre agências usam httpx com timeout de 1 segundo; uma agência fora do ar
    ou que não responde a tempo é tratada como inativa.
    """

    def __init__(self, id_agencia: int, relogio, registro) -> None:
        self.id_agencia = id_agencia
        self.relogio = relogio
        self.registro = registro
        self._lider_atual: int | None = None
        self._eleicao_em_andamento = False
        self._lock = Lock()
        self._tarefas: set[asyncio.Task] = set()
        self._historico: deque[dict] = deque(maxlen=20)

    def _registrar_historico(self, lider: int | None, motivo: str) -> None:
        # Guarda as definições de líder vistas por esta agência (para o app exibir).
        anterior = self._historico[-1]["liderAtual"] if self._historico else None
        self._historico.append({
            "liderAtual": lider,
            "horaParede": datetime.now(timezone.utc).isoformat(),
            "motivo": motivo,
            "mudou": lider != anterior,
        })

    def historico(self) -> list[dict]:
        with self._lock:
            return list(reversed(self._historico))

    def _agencias_com_id_maior(self) -> list[dict]:
        return [agencia for agencia in AGENCIAS if agencia["id"] > self.id_agencia]

    def _cliente(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(trust_env=False, timeout=TIMEOUT_SEGUNDOS)

    def _em_segundo_plano(self, corrotina) -> None:
        tarefa = asyncio.create_task(corrotina)
        self._tarefas.add(tarefa)
        tarefa.add_done_callback(self._tarefas.discard)

    async def iniciar_eleicao(self) -> None:
        with self._lock:
            if self._eleicao_em_andamento:
                return
            self._eleicao_em_andamento = True

        alguem_respondeu = False
        try:
            vetor = self.relogio.evento_local()
            self.registro.registrar("ELEICAO_INICIADA", vetor, {"idAgencia": self.id_agencia})

            async with self._cliente() as cliente:
                for agencia in self._agencias_com_id_maior():
                    try:
                        vetor_envio = self.relogio.ao_enviar()
                        resposta = await cliente.post(
                            f"{agencia['url']}/bully/eleicao",
                            json={"origemId": self.id_agencia, "vetorEnvio": vetor_envio},
                        )
                        resposta.raise_for_status()
                        alguem_respondeu = True
                    except httpx.HTTPError:
                        # agência fora do ar ou não respondeu a tempo - ignora e segue
                        pass
        finally:
            with self._lock:
                self._eleicao_em_andamento = False

        if not alguem_respondeu:
            await self._tornar_me_lider()
        # Se alguma agência maior respondeu, é ela quem conduz a própria eleição
        # e anuncia o resultado em /bully/coordenador.

    async def _tornar_me_lider(self) -> None:
        with self._lock:
            self._lider_atual = self.id_agencia
            self._registrar_historico(self.id_agencia, "venceu a eleição nesta agência")
        vetor = self.relogio.evento_local()
        self.registro.registrar("TORNOU_LIDER", vetor, {"idAgencia": self.id_agencia})

        async with self._cliente() as cliente:
            for agencia in AGENCIAS:
                if agencia["id"] == self.id_agencia:
                    continue
                try:
                    vetor_envio = self.relogio.ao_enviar()
                    await cliente.post(
                        f"{agencia['url']}/bully/coordenador",
                        json={"liderId": self.id_agencia, "vetorEnvio": vetor_envio},
                    )
                except httpx.HTTPError:
                    # agência fora do ar - descobre a líder quando voltar
                    pass

    def receber_eleicao(self, origem_id: int, vetor_recebido: list[int]) -> None:
        vetor = self.relogio.ao_receber(vetor_recebido)
        self.registro.registrar(
            "ELEICAO_RECEBIDA", vetor, {"de": origem_id, "minhaId": self.id_agencia},
        )
        # O 200 da rota já serve como "OK". A eleição própria roda em segundo
        # plano, pois esta agência tem ID maior que a de origem e pode ser a líder.
        self._em_segundo_plano(self.iniciar_eleicao())

    def receber_coordenador(self, lider_id: int, vetor_recebido: list[int]) -> None:
        with self._lock:
            self._lider_atual = lider_id
            self._registrar_historico(lider_id, f"anunciada pela Agência {lider_id}")
        vetor = self.relogio.ao_receber(vetor_recebido)
        self.registro.registrar(
            "LIDER_ANUNCIADO", vetor, {"liderId": lider_id, "agencia": self.id_agencia},
        )

    def obter_lider_atual(self) -> int | None:
        with self._lock:
            return self._lider_atual

    async def verificar_lider(self) -> None:
        lider = self.obter_lider_atual()
        if lider is None:
            await self.iniciar_eleicao()
            return
        if lider == self.id_agencia:
            return  # eu sou a líder, nada a verificar

        lider_info = obter_agencia(lider)
        try:
            if lider_info is None:
                raise httpx.ConnectError(f"agência {lider} não configurada")
            async with self._cliente() as cliente:
                resposta = await cliente.get(f"{lider_info['url']}/bully/lider")
                resposta.raise_for_status()
        except httpx.HTTPError:
            vetor = self.relogio.evento_local()
            self.registro.registrar(
                "LIDER_NAO_RESPONDEU", vetor, {"liderAtual": lider, "agencia": self.id_agencia},
            )
            with self._lock:
                if self._lider_atual == lider:
                    self._lider_atual = None
                    self._registrar_historico(None, f"a Agência {lider} parou de responder")
            await self.iniciar_eleicao()

    async def _heartbeat(self, intervalo: float) -> None:
        while True:
            await asyncio.sleep(intervalo)
            try:
                await self.verificar_lider()
            except Exception as erro:  # noqa: BLE001 - o heartbeat não pode parar
                print(f"[Bully] falha no heartbeat: {erro!r}", flush=True)

    def iniciar_heartbeat(self, intervalo: float = INTERVALO_HEARTBEAT_SEGUNDOS) -> None:
        self._em_segundo_plano(self._heartbeat(intervalo))

    def forcar_eleicao(self) -> bool:
        """Eleição sob demanda (ex.: botão no app). Retorna False se já há uma em andamento."""
        with self._lock:
            em_andamento = self._eleicao_em_andamento
        if em_andamento:
            return False
        vetor = self.relogio.evento_local()
        self.registro.registrar("ELEICAO_SOB_DEMANDA", vetor, {"idAgencia": self.id_agencia})
        self._em_segundo_plano(self.iniciar_eleicao())
        return True

    def iniciar(self) -> None:
        """Dispara a eleição inicial, depois que a agência já aceita conexões."""
        self._em_segundo_plano(self.iniciar_eleicao())

    def parar(self) -> None:
        for tarefa in list(self._tarefas):
            tarefa.cancel()
