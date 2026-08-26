# Respostas — Sprint 1: ICEIBank

## Parte B — Relógio de Lamport

### 1. Por que usar `max(contador_local, timestamp_recebido) + 1`?

O `max` evita que o relógio volte caso a mensagem tenha um timestamp menor. O `+ 1` registra o recebimento como um novo evento, depois da mensagem recebida.

### 2. Agência no contador 10 recebendo timestamp 3

O novo valor será `11`. Isso mostra que uma agência pode ter um contador maior por processar mais eventos. Esse contador não representa o tempo real.

## Parte D — Transferências

### 1. Por que a transferência local não usa `aoEnviar()` e `aoReceber()`?

Porque as duas contas estão na mesma agência e não existe comunicação entre processos. Na transferência entre agências, uma mensagem é enviada e recebida, por isso essas operações são necessárias.

### 2. O saldo foi revertido depois da falha?

Não. O saldo caiu de 20 para 10 mesmo com a falha. Isso deixa o sistema inconsistente, porque o valor saiu da origem e não chegou ao destino.

### 3. Duas formas de corrigir o problema no Sprint 4

Uma opção é usar 2PC, confirmando a operação nas duas agências antes de concluí-la. Outra opção é usar Saga, fazendo uma operação de compensação para devolver o valor quando o crédito falhar.
