import json
from pathlib import Path


PASTA_DADOS = Path(__file__).resolve().parent / "data"


def carregar_eventos() -> list[dict]:
    eventos = []
    for caminho in sorted(PASTA_DADOS.glob("*.jsonl")):
        with caminho.open(encoding="utf-8") as arquivo:
            for linha in arquivo:
                if linha.strip():
                    eventos.append(json.loads(linha))
    return eventos


def main() -> None:
    eventos = carregar_eventos()
    eventos.sort(key=lambda evento: evento["timestampLamport"])

    print("=== Linha do tempo unificada (ordenada por relogio de Lamport) ===")
    if not eventos:
        print("Nenhum evento encontrado em agencia/data.")
        return

    for evento in eventos:
        detalhes = json.dumps(evento["detalhes"], ensure_ascii=False)
        print(
            f"[Lamport {evento['timestampLamport']}] "
            f"({evento['horaParede']}) "
            f"{evento['agencia']} - {evento['tipo']} {detalhes}"
        )


if __name__ == "__main__":
    main()
