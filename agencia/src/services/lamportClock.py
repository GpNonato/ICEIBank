from threading import Lock


class RelogioLamport:
    def __init__(self) -> None:
        self.contador = 0
        self._lock = Lock()

    def evento_local(self) -> int:
        with self._lock:
            self.contador += 1
            return self.contador

    def ao_enviar(self) -> int:
        with self._lock:
            self.contador += 1
            return self.contador

    def ao_receber(self, timestamp_recebido: int) -> int:
        with self._lock:
            self.contador = max(self.contador, timestamp_recebido) + 1
            return self.contador

    def valor_atual(self) -> int:
        with self._lock:
            return self.contador
