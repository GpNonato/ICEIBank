def comparar_vetores(v1: list[int], v2: list[int]) -> str:
    """Relação causal entre dois relógios vetoriais: IGUAIS, ANTES, DEPOIS ou CONCORRENTES."""
    v1_menor_ou_igual = all(a <= b for a, b in zip(v1, v2))
    v2_menor_ou_igual = all(b <= a for a, b in zip(v1, v2))
    if v1_menor_ou_igual and v2_menor_ou_igual:
        return "IGUAIS"
    if v1_menor_ou_igual:
        return "ANTES"
    if v2_menor_ou_igual:
        return "DEPOIS"
    return "CONCORRENTES"
