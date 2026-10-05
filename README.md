# ICEIBank

API REST distribuída desenvolvida em Python com FastAPI. A partir do Sprint 2, as
transferências entre agências são entregues por mensageria (RabbitMQ, padrão
Publish/Subscribe) e os eventos são ordenados com relógio vetorial.

## Instalar as dependências

Na pasta `agencia`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## Configurar o RabbitMQ

As agências se conectam ao RabbitMQ pela variável `RABBITMQ_URL`. Copie
`agencia/.env.example` para `agencia/.env` e informe a AMQP URL da sua instância
CloudAMQP. O arquivo `.env` é carregado automaticamente e fica fora do Git, pois
contém usuário e senha:

```text
RABBITMQ_URL=amqps://usuario:senha@host.cloudamqp.com/vhost
```

Também é possível definir a variável no terminal (`$env:RABBITMQ_URL="..."`) ou usar
um RabbitMQ local (`amqp://localhost`).

Topologia criada pelas agências:

- exchange `iceibank.eventos` do tipo `topic`, durável;
- uma fila durável por agência (`fila-agencia-0`, `fila-agencia-1`, `fila-agencia-2`),
  ligada pela routing key `agencia.<id>.creditar`;
- mensagens publicadas como persistentes.

Para ver quantas mensagens estão retidas em cada fila, sem abrir o painel do CloudAMQP:

```powershell
.\.venv\Scripts\python.exe inspecionar-filas.py
```

## Executar as agências

Abra três terminais na pasta `agencia`. Em cada um, use um ID diferente:

```powershell
$env:AGENCIA_ID=0
.\.venv\Scripts\python.exe -m src.app
```

Use os IDs `0`, `1` e `2`. Com o offset configurado, as agências usam as portas 4042, 4043 e 4044.

Uma transferência entre agências debita a origem e publica o crédito na exchange. A
resposta HTTP 200 significa que a mensagem foi publicada; o crédito é aplicado quando a
agência de destino consome a fila, mesmo que ela esteja fora do ar no momento da
publicação.

## Linha do tempo causal

Cada agência grava seus eventos em `agencia/data/eventos-agencia-<id>.jsonl` com o
relógio vetorial (`timestampVetorial`). Para unir os logs e identificar os pares de
eventos concorrentes entre agências diferentes:

```powershell
.\.venv\Scripts\python.exe mesclar-logs.py
```

O script lista os eventos por hora de parede, compara os vetores de todos os pares de
agências diferentes e mostra, para cada transferência entre agências, a relação causal
entre a publicação e o recebimento.

## Terminal web

Com as agências no ar, abra `http://localhost:4042` no navegador. A pasta `frontend/`
(HTML, CSS e JS puros, sem build) é servida pela própria agência, então não é
preciso subir outro servidor.

Comandos disponíveis (digite `ajuda` para listar):

```text
entrar <usuario> <senha>                    autentica e guarda o token
agencia <0|1|2>                             troca a agência conectada
saldo <conta>                               mostra titular, agência e saldo
depositar <conta> <valor>                   credita um valor na conta
sacar <conta> <valor>                       debita um valor da conta
transferir <origem> <destino> <valor> [id]  transferência local ou entre agências
criar <conta> <nome> <saldo>                abre uma conta na agência conectada
historico <conta>                           lista os eventos da conta
limites                                     mostra os limites por operação
extrato <nome>                              consolida contas nas três agências
status [agencia]                            mostra relógio e quantidade de contas
swagger [agencia]                           abre a documentação da agência
sair                                        encerra a sessão e remove o token
```

O terminal aceita `Tab` para completar comandos, `↑`/`↓` para navegar no
histórico e mostra o endpoint chamado à direita de cada comando. O token fica em
`localStorage` e a sessão é retomada ao recarregar a página, até expirar.

Como o comando `agencia` chama as outras portas, cada agência libera via CORS as
origens das demais (`localhost` e `127.0.0.1` nas portas 4042-4044).

## Funcionalidades adicionais do Sprint 2

### Fila de auditoria

Um consumidor separado assina a exchange com a routing key `#` e recebe uma cópia de
todas as mensagens publicadas por todas as agências. Cada mensagem é gravada em
`agencia/data/auditoria/auditoria-central.jsonl`. A fila `fila-auditoria` é durável:
se o auditor estiver parado, as mensagens ficam retidas até ele voltar.

```powershell
.\.venv\Scripts\python.exe -m src.auditoria
```

### Notificação de saldo baixo

Depois de um saque ou de uma transferência, se o saldo da conta ficar abaixo de
R$ 50,00, a agência publica um alerta na routing key
`agencia.<id>.alerta.saldo-baixo`. Esse tópico é separado do tópico de crédito, então
não chega às filas das agências; a fila de auditoria recebe o alerta e o destaca com
`[ALERTA]`. O limite pode ser alterado pela variável `LIMITE_SALDO_BAIXO` e aparece no
comando `limites` do terminal web.

### Confirmação de entrega

Depois de processar um crédito, a agência de destino publica uma confirmação na routing
key `agencia.<origem>.confirmacao`, com `status` `creditado` ou `falhou` (e o motivo).
A fila da agência de origem também está ligada a essa routing key; ao consumir a
confirmação, a origem atualiza o relógio vetorial e a situação da transferência. A
situação pode ser consultada em `GET /transferencias/{idOperacao}` ou, no terminal web,
com `situacao <id-operacao>`:

- `aguardando confirmação`: o crédito foi publicado e ainda não houve resposta;
- `creditada no destino`: o destino aplicou o crédito;
- `crédito não aplicado no destino`: o destino não conseguiu aplicar o crédito.

## Funcionalidades adicionais do Sprint 1

O sistema possui histórico por conta, limite de R$ 1.000,00 por saque e transferência, extrato consolidado entre as três agências, idempotência de transferências e rota de status. Os limites podem ser alterados pelas variáveis `LIMITE_SAQUE` e `LIMITE_TRANSFERENCIA`.

Para demonstrar a idempotência, repita uma transferência com o mesmo identificador:

```text
transferir 0 1 10 demonstracao-1
transferir 0 1 10 demonstracao-1
```

A segunda chamada será reconhecida e não movimentará o saldo novamente.

## Autenticação

O endpoint `POST /auth/login` recebe `usuario` e `senha`. As credenciais locais padrão são:

```text
usuario: gabriel
senha: iceibank123
```

Em outro ambiente, configure `ICEIBANK_USUARIO`, `ICEIBANK_SENHA` e `JWT_SECRET` antes de iniciar as agências. O token expira em 15 minutos por padrão.
