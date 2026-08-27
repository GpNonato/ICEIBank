import json
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock


class RegistroEventos:
    def __init__(self, nome_agencia: str) -> None:
        self.nome_agencia = nome_agencia
        pasta_dados = Path(__file__).resolve().parents[2] / "data"
        pasta_dados.mkdir(parents=True, exist_ok=True)
        self.caminho_arquivo = pasta_dados / f"eventos-{nome_agencia}.jsonl"
        self._lock = Lock()

    def registrar(self, tipo: str, timestamp_lamport: int, detalhes: dict) -> dict:
        evento = {
            "agencia": self.nome_agencia,
            "tipo": tipo,
            "timestampLamport": timestamp_lamport,
            "horaParede": datetime.now(timezone.utc).isoformat(),
            "detalhes": detalhes,
        }
        with self._lock:
            with self.caminho_arquivo.open("a", encoding="utf-8") as arquivo:
                arquivo.write(json.dumps(evento, ensure_ascii=False) + "\n")
        print(f"[Lamport {timestamp_lamport}] {tipo} {detalhes}", flush=True)
        return evento
