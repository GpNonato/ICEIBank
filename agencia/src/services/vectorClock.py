from threading import Lock


class RelogioVetorial:
    def __init__(self, id_agencia: int, numero_agencias: int) -> None:
        self.id_agencia = id_agencia
        self.vetor = [0] * numero_agencias
        self._lock = Lock()

    def evento_local(self) -> list[int]:
        with self._lock:
            self.vetor[self.id_agencia] += 1
            return list(self.vetor)

    def ao_enviar(self) -> list[int]:
        with self._lock:
            self.vetor[self.id_agencia] += 1
            return list(self.vetor)

    def ao_receber(self, vetor_recebido: list[int]) -> list[int]:
        with self._lock:
            for i in range(len(self.vetor)):
                self.vetor[i] = max(self.vetor[i], vetor_recebido[i])
            self.vetor[self.id_agencia] += 1
            return list(self.vetor)

    def valor_atual(self) -> list[int]:
        with self._lock:
            return list(self.vetor)
