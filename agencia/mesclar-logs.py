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


def comparar_vetores(v1: list[int], v2: list[int]) -> str:
    v1_menor_ou_igual = all(a <= b for a, b in zip(v1, v2))
    v2_menor_ou_igual = all(b <= a for a, b in zip(v1, v2))
    if v1_menor_ou_igual and v2_menor_ou_igual:
        return "IGUAIS"
    if v1_menor_ou_igual:
        return "ANTES"
    if v2_menor_ou_igual:
        return "DEPOIS"
    return "CONCORRENTES"


def descrever(evento: dict) -> str:
    return f"[{evento['agencia']}] {evento['tipo']} ({evento['timestampVetorial']})"


def main() -> None:
    eventos = carregar_eventos()
    eventos.sort(key=lambda evento: evento["horaParede"])

    print("=== Linha do tempo (ordenada por hora de parede) ===")
    if not eventos:
        print("Nenhum evento encontrado em agencia/data.")
        return

    for evento in eventos:
        detalhes = json.dumps(evento["detalhes"], ensure_ascii=False)
        print(f"[{evento['agencia']}] vetor={evento['timestampVetorial']} {evento['tipo']} {detalhes}")

    print("\n=== Pares de eventos CONCORRENTES entre agências diferentes ===")
    concorrentes = 0
    for i, e1 in enumerate(eventos):
        for e2 in eventos[i + 1:]:
            if e1["agencia"] == e2["agencia"]:
                continue
            if comparar_vetores(e1["timestampVetorial"], e2["timestampVetorial"]) == "CONCORRENTES":
                concorrentes += 1
                print(f"{descrever(e1)}  x  {descrever(e2)}")
    if concorrentes == 0:
        print("(nenhum par concorrente encontrado nesta execução - gere mais eventos em paralelo e rode de novo)")
    else:
        print(f"Total: {concorrentes} par(es) concorrente(s).")

    print("\n=== Transferências entre agências (envio x recebimento) ===")
    envios = {
        evento["detalhes"]["idOperacao"]: evento
        for evento in eventos
        if evento["tipo"] == "TRANSFERENCIA_PUBLICADA"
    }
    recebimentos = [
        evento for evento in eventos
        if evento["tipo"] in ("TRANSFERENCIA_CREDITO_REMOTO", "CREDITO_REMOTO_FALHOU")
        and evento["detalhes"].get("idOperacao") in envios
    ]
    if not recebimentos:
        print("(nenhuma transferência entre agências registrada)")
    for recebimento in recebimentos:
        envio = envios[recebimento["detalhes"]["idOperacao"]]
        relacao = comparar_vetores(envio["timestampVetorial"], recebimento["timestampVetorial"])
        print(f"{descrever(envio)}  {relacao}  {descrever(recebimento)}")


if __name__ == "__main__":
    main()
