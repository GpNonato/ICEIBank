import json
from datetime import datetime
from pathlib import Path


PASTA_DADOS = Path(__file__).resolve().parent / "data"
TIPOS_BULLY = (
    "ELEICAO_INICIADA",
    "ELEICAO_RECEBIDA",
    "TORNOU_LIDER",
    "LIDER_ANUNCIADO",
    "LIDER_NAO_RESPONDEU",
)


def carregar_eventos() -> list[dict]:
    eventos = []
    for caminho in sorted(PASTA_DADOS.glob("*.jsonl")):
        with caminho.open(encoding="utf-8") as arquivo:
            for linha in arquivo:
                if linha.strip():
                    eventos.append(json.loads(linha))
    return eventos


def hora(evento: dict) -> str:
    # horaParede é gravada em UTC; aqui é exibida no fuso local, com milissegundos.
    return datetime.fromisoformat(evento["horaParede"]).astimezone().strftime("%H:%M:%S.%f")[:-3]


def main() -> None:
    eventos = [evento for evento in carregar_eventos() if evento["tipo"] in TIPOS_BULLY]
    eventos.sort(key=lambda evento: evento["horaParede"])

    print("=== Histórico de eventos de eleição ===")
    if not eventos:
        print("Nenhum evento de eleição encontrado em agencia/data.")
        return
    for evento in eventos:
        detalhes = json.dumps(evento["detalhes"], ensure_ascii=False)
        print(f"({hora(evento)}) [{evento['agencia']}] {evento['tipo']} {detalhes}")

    print("\n=== Linha do tempo de líderes ===")
    lider_anterior = None
    trocas = 0
    for evento in eventos:
        if evento["tipo"] == "LIDER_NAO_RESPONDEU":
            print(
                f"{hora(evento)}  [{evento['agencia']}] a líder "
                f"Agência {evento['detalhes']['liderAtual']} parou de responder"
            )
        elif evento["tipo"] == "TORNOU_LIDER":
            lider = evento["detalhes"]["idAgencia"]
            if lider == lider_anterior:
                print(f"A partir de {hora(evento)}: Agência {lider} é a líder (reeleita)")
                continue
            if lider_anterior is not None:
                trocas += 1
            print(f"A partir de {hora(evento)}: Agência {lider} é a líder")
            lider_anterior = lider

    total = sum(1 for evento in eventos if evento["tipo"] == "TORNOU_LIDER")
    print(f"\nTORNOU_LIDER registrado {total} vez(es); a liderança mudou de mãos {trocas} vez(es).")


if __name__ == "__main__":
    main()
