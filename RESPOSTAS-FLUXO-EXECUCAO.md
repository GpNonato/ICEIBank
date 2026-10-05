# Respostas — Comunicação indireta: Mensageria, Pub/Sub e Relógio Vetorial

Atividade de recapitulação do sistema desenvolvido. As respostas usam o código do ICEIBank e as execuções registradas em `evidencias/sprint2/`.

### 1. Arquitetura atual e divisão em agências

A aplicação roda em três processos FastAPI iguais (`agencia/src/app.py`), iniciados com `AGENCIA_ID` 0, 1 e 2 nas portas 4042, 4043 e 4044. Cada agência guarda em memória as próprias contas, tem um relógio vetorial e grava seus eventos em `agencia/data/eventos-agencia-<id>.jsonl`. O frontend (`frontend/`) é servido pela própria agência e chama a API com JWT. O RabbitMQ, hospedado no CloudAMQP, é o intermediário das mensagens entre as agências. Há também um consumidor de auditoria opcional (`src.auditoria`).

Uma conta pertence à agência `id % 3` (`agencia_responsavel` em `config.py`). Criar conta, consultar saldo, depositar, sacar, ver histórico e transferir entre contas da mesma agência são operações locais. A transferência para uma conta de outra agência e o extrato consolidado dependem das outras agências.

**Resumo:** os participantes são as três agências, o RabbitMQ e o auditor. As fronteiras de comunicação são a transferência entre agências e o extrato consolidado.

### 2. Comunicação atual entre as agências

No Sprint 1, a agência de origem chamava `POST /contas/{id}/creditar-remoto` na agência de destino com `httpx`, usando um JWT do tipo `agencia`, e esperava a resposta. Se o destino estava fora do ar, a chamada falhava, a API retornava HTTP 502 e o débito já aplicado ficava sem crédito. Se o destino demorava, a requisição do cliente ficava presa até o timeout.

No Sprint 2, a transferência passou a usar o RabbitMQ. O extrato consolidado continua usando REST (`GET /interno/contas`). Por isso, ele ainda falha com 502 quando uma das agências está indisponível.

**Resumo:** a chamada direta acopla as agências no tempo, pois as duas precisam estar no ar ao mesmo tempo. Esse é o motivo para usar comunicação indireta.

### 3. Operações distribuídas e seus efeitos

Transferência de R$ 30,00 da conta 0 (Agência 0) para a conta 1 (Agência 1):

1. O cliente chama `POST /transferencias` na Agência 0 com JWT.
2. A Agência 0 valida a conta, o limite e o saldo, debita a conta 0 e registra `TRANSFERENCIA_DEBITO` (`[2, 0, 0]`).
3. A Agência 0 publica a mensagem de crédito e registra `TRANSFERENCIA_PUBLICADA` (`[3, 0, 0]`). O cliente recebe HTTP 200.
4. A Agência 1 consome a mensagem, credita a conta 1 e registra `TRANSFERENCIA_CREDITO_REMOTO` (`[3, 2, 0]`).
5. A Agência 1 publica a confirmação e a Agência 0 registra `CONFIRMACAO_CREDITO`.

Para o cliente, a operação termina no passo 3, quando a mensagem é publicada. O dinheiro só chega ao destino no passo 4, e a origem só sabe disso no passo 5. A situação pode ser consultada em `GET /transferencias/{idOperacao}`.

**Resumo:** os eventos distribuídos são o envio do crédito e a confirmação do crédito.

### 4. Eventos que precisam ser comunicados

| Evento | Routing key | Produtor | Consumidores |
| --- | --- | --- | --- |
| Pedido de crédito | `agencia.<destino>.creditar` | agência de origem | agência de destino e auditoria |
| Confirmação de crédito | `agencia.<origem>.confirmacao` | agência de destino | agência de origem e auditoria |
| Alerta de saldo baixo | `agencia.<id>.alerta.saldo-baixo` | agência da conta | auditoria |

Exemplo de pedido de crédito:

```json
{"idConta": 1, "idOrigem": 0, "valor": 30.0, "vetorEnvio": [3, 0, 0], "origemAgencia": 0, "idOperacao": "assinc-01"}
```

Exemplo de confirmação:

```json
{"idOperacao": "extra-01", "idConta": 1, "valor": 60.0, "status": "creditado", "agenciaDestino": 1, "vetorEnvio": [3, 3, 0]}
```

**Resumo:** cada evento tem um tópico próprio. Quem publica não precisa saber quem consome.

### 5. Mensageria e comunicação indireta

```text
Agência 0 --publica--> exchange iceibank.eventos (topic)
                          | agencia.1.creditar          -> fila-agencia-1 -> Agência 1
                          | agencia.0.confirmacao       -> fila-agencia-0 -> Agência 0
                          | agencia.0.alerta.saldo-baixo
                          | # (todas as chaves)         -> fila-auditoria -> Auditoria
```

O produtor é a agência de origem. O canal é a exchange `iceibank.eventos`, do tipo `topic`. Cada agência tem uma fila durável ligada às suas routing keys. O consumidor principal é a agência de destino, e a auditoria recebe uma cópia de tudo. A mensagem leva a conta, o valor, a agência de origem, o `idOperacao` e o vetor de envio. A exchange e as filas são duráveis e a mensagem é persistente, por isso ela não se perde se o destino estiver fora do ar.

**Resumo:** o fluxo foi implementado em `services/mensageria.py` e `controllers/transferenciasController.py`.

### 6. Entrega, duplicidade e processamento de mensagens

**Duplicidade:** se a Agência 1 aplicar o crédito e cair antes de confirmar a mensagem ao RabbitMQ (ack), a mensagem é entregue de novo e o crédito pode ser aplicado duas vezes. Para evitar isso, cada mensagem leva o `idOperacao` e a agência guarda os créditos já aplicados em `creditos_processados`. Uma repetição gera `CREDITO_REMOTO_REPETIDO` sem alterar o saldo. Como esse controle fica em memória, ele se perde se a agência reiniciar.

**Falha e reprocessamento:** no teste de resiliência, a mensagem chegou depois de a Agência 1 reiniciar e a conta já não existia. A mensagem agora volta para a fila e é tentada até 3 vezes. Depois disso, ela vai para a `fila-mensagens-mortas` e a origem recebe uma confirmação com `status: falhou`.

**Fora de ordem:** durante os testes, a confirmação chegou à Agência 0 antes de ela terminar a requisição da transferência. O registro ainda estava incompleto e o processamento falhou. A correção foi guardar os dados da transferência antes de publicar.

Para processar uma mensagem com segurança, são necessários: um identificador único da operação (`idOperacao`), um identificador da mensagem (`message_id`), a agência de origem, o vetor de envio, o número de tentativas e o registro persistente das operações já aplicadas.

**Resumo:** idempotência por `idOperacao`, novas tentativas limitadas e dead-letter queue.

### 7. Eventos concorrentes e ordenação causal

No teste da Parte D, a Agência 0 publicou a transferência `causal-01` e a Agência 1 aplicou o crédito. Ao ordenar os logs pela hora de parede, `TRANSFERENCIA_CREDITO_REMOTO` apareceu antes de `TRANSFERENCIA_PUBLICADA`. Isso aconteceu porque a Agência 0 só grava a publicação depois do ack do RabbitMQ, e nesse intervalo a Agência 1 já tinha consumido a mensagem.

Outro cenário: a Agência 0 e a Agência 2 enviam créditos para a Agência 1 quase ao mesmo tempo. A ordem em que a Agência 1 recebe as mensagens depende da rede e do broker, e não diz qual operação aconteceu primeiro.

Se a análise usar a ordem de recebimento ou a hora de parede, ela pode concluir que um crédito aconteceu antes do envio, ou que uma operação causou outra sem ter relação com ela. Isso atrapalha auditorias e a investigação de problemas.

**Resumo:** a ordem local é a de cada agência, a ordem de recebimento é a de cada fila e a relação causal só aparece com o relógio vetorial.

### 8. Relógio vetorial na aplicação

O vetor tem três posições, uma por agência: `[agência 0, agência 1, agência 2]`. Ele é atualizado em três momentos:

- evento local (criar conta, depósito, saque, débito): `evento_local()` incrementa a posição da agência;
- envio (crédito, confirmação, alerta): `ao_enviar()` incrementa a posição e o vetor vai no campo `vetorEnvio`;
- recebimento: `ao_receber(vetorEnvio)` faz o máximo posição a posição e incrementa a posição da agência.

Para comparar dois eventos, compara-se cada posição dos vetores (`comparar_vetores` em `mesclar-logs.py`).

- Concorrentes: `[agencia-0] CRIAR_CONTA [1, 0, 0]` e `[agencia-2] CRIAR_CONTA [0, 0, 1]`. Cada um tem uma posição maior que a do outro.
- Causalmente relacionados: `TRANSFERENCIA_PUBLICADA [3, 0, 0]` e `TRANSFERENCIA_CREDITO_REMOTO [3, 2, 0]`. Todas as posições do primeiro são menores ou iguais às do segundo, então o envio aconteceu antes do crédito. A confirmação continua a cadeia: `CONFIRMACAO_PUBLICADA [3, 3, 0]` e depois `CONFIRMACAO_CREDITO [5, 3, 0]` na Agência 0.

**Resumo:** implementado em `services/vectorClock.py` e usado nos controllers e no consumidor.

### 9. Consistência e observabilidade dos eventos

Cada evento do log guarda `agencia`, `tipo`, `timestampVetorial`, `horaParede` e `detalhes`. Os detalhes incluem o `idOperacao`, as contas e a `routingKey`. Cada mensagem leva `vetorEnvio`, `origemAgencia`, `idOperacao` e um `message_id`. Com esses dados:

- o `mesclar-logs.py` diz se uma mensagem foi produzida antes ou depois de outra e lista os pares concorrentes;
- para saber se uma agência recebeu informação causada por outra, basta olhar a posição da outra agência no vetor. Em `[3, 2, 0]`, a Agência 1 já conhece 3 eventos da Agência 0;
- a auditoria central guarda todas as mensagens publicadas;
- o `inspecionar-filas.py` mostra as mensagens retidas e as mensagens mortas, com o cabeçalho `x-death`.

**Resumo:** os logs `.jsonl`, o log de auditoria e os scripts de análise formam a instrumentação dos experimentos.

### 10. Proposta de evolução para a próxima implementação

A operação modificada foi a transferência entre agências. A chamada REST direta foi substituída pela publicação na exchange `iceibank.eventos`. Participam a agência de origem, a agência de destino, o RabbitMQ e a auditoria. As mensagens trocadas são o pedido de crédito, a confirmação e o alerta de saldo baixo. Os metadados adicionados foram o `vetorEnvio`, o `idOperacao`, a `origemAgencia` e o `message_id`.

A implementação foi demonstrada com quatro experimentos:

1. transferência assíncrona com as três agências no ar (`transferencia-assincrona.png`);
2. agência de destino fora do ar, com a mensagem retida na fila e entregue na volta (`resiliencia-fila.png`);
3. linha do tempo com pares concorrentes e com a transferência classificada como `ANTES` (`linha-do-tempo-causal.png`);
4. crédito com falha repetida enviado para a dead-letter queue, com confirmação de falha para a origem (`funcionalidade-adicional.png`).

Os próximos passos são persistir as contas e o controle de idempotência, assinar as mensagens e devolver automaticamente o valor quando o crédito falhar (Saga, no Sprint 4).

**Resumo:** a proposta já está implementada no Sprint 2. Os pontos em aberto ficam para os próximos sprints.
