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

## Parte E — Linha do tempo unificada

### Observação da linha do tempo

As três agências registraram `CRIAR_CONTA` com timestamp Lamport 1. Esses eventos são concorrentes, pois aconteceram de forma independente. Também houve dois eventos com timestamp 2, e a ordem mostrada não foi a mesma da hora de parede.

### 1. Timestamps diferentes garantem relação causal?

Não. Se um evento causou outro, seu timestamp será menor. Mas apenas ver timestamps diferentes não prova que um evento influenciou o outro.

### 2. O relógio de Lamport distingue concorrência com certeza?

Não. Ele ordena os eventos, mas não identifica sozinho se eles são concorrentes. O relógio vetorial resolve essa limitação ao guardar o progresso de cada processo.

## Parte F — Autenticação JWT

### Decisões de implementação

O login usa usuário e senha, pois é uma forma simples de autenticação para este sprint, que ainda não possui banco de dados de usuários. As credenciais podem ser alteradas por variáveis de ambiente. O token expira em 15 minutos.

As chamadas entre agências usam um JWT próprio com o tipo `agencia`. Assim, o crédito remoto continua protegido sem usar o token da pessoa que iniciou a transferência.

### 1. Diferença entre autenticação e autorização

Autenticação confirma quem está acessando. Autorização define o que essa pessoa pode fazer. O sistema distingue tokens de usuário e de agência, mas ainda não verifica o dono da conta. Portanto, um usuário autenticado consegue operar qualquer conta.

### 2. Por que o JWT não exige consulta ao banco de dados?

Porque o servidor verifica a assinatura usando a chave secreta. Isso facilita a escalabilidade, pois diferentes instâncias podem validar o token sem compartilhar sessões em memória.

### 3. O que acontece se a chave secreta vazar?

Quem possuir a chave poderá criar tokens válidos e se passar por usuários ou agências. Nesse caso, a chave precisa ser trocada e os tokens antigos devem deixar de ser aceitos.

## Parte G — Frontend

### Decisões de implementação

O frontend foi desenvolvido com HTML, CSS e JavaScript puro, sem framework e sem processo de build. A interface segue o estilo de um terminal bancário e é servida pela própria API. O comando `agencia` permite selecionar qualquer uma das três agências.

### 1. Como o frontend reenvia o token?

Depois do login, o token é salvo no `localStorage`. Antes de cada chamada protegida, o JavaScript adiciona o cabeçalho `Authorization: Bearer <token>`.

### 2. O que acontece quando o token expira?

Quando a API retorna HTTP 401, a interface mostra a mensagem de erro, remove o token salvo e encerra a sessão. A pessoa precisa executar o login novamente.

### 3. Onde estão Model, View e Controller?

O Model está nas funções que fazem as chamadas à API e guardam o estado. A View está no `index.html`, no `styles.css` e na saída exibida no terminal. O Controller está no `app.js`, que interpreta os comandos e coordena a interface com a API. Como o projeto é pequeno, Model e Controller ficam no mesmo arquivo JavaScript.

## Funcionalidade adicional escolhida — Seção 2.1

A funcionalidade escolhida foi a idempotência de transferências. Ela foi escolhida porque uma requisição pode ser reenviada por falha de rede ou repetição da pessoa usuária. Sem idempotência, o mesmo débito poderia ser aplicado duas vezes. Cada transferência recebe um identificador único e, quando ele é repetido, o sistema retorna o resultado anterior sem movimentar novamente os saldos.

Além da funcionalidade escolhida, foram implementados outros recursos complementares.

### Histórico de transações por conta

O endpoint `GET /contas/{id}/historico` filtra o registro de eventos e mostra apenas as operações relacionadas à conta informada. No frontend, ele é acessado com `historico <conta>`.

### Limite por operação

Saques e transferências possuem limite padrão de R$ 1.000,00 por operação. A regra reduz o risco de uma movimentação muito alta e pode ser configurada por variável de ambiente. O comando `limites` mostra os valores atuais.

### Extrato consolidado

O endpoint `GET /extratos/consolidado/{nome}` consulta as três agências usando autenticação interna e soma os saldos das contas que possuem o mesmo titular. No frontend, ele é acessado com `extrato <nome>`.

### Idempotência de transferências

Cada transferência possui um identificador de operação. Se a mesma requisição for repetida com o mesmo identificador, o sistema retorna o resultado anterior sem aplicar outro débito ou crédito.

### Status da agência

O endpoint `GET /status` informa se a agência está disponível, o valor atual do relógio de Lamport e a quantidade de contas em memória. O frontend permite consultar com `status <agencia>`.

### Acesso ao Swagger

O comando `swagger <agencia>` abre a documentação da agência escolhida em uma nova aba do navegador.

## Declaração de uso de IA

Foi utilizada IA para a criação do frontend e revisão das respostas.


# Respostas — Sprint 2: ICEIBank

## Parte B — Relógio vetorial

### Decisões de implementação

O relógio vetorial fica em `agencia/src/services/vectorClock.py` e segue as três regras do roteiro: `evento_local()` e `ao_enviar()` incrementam a posição da própria agência, e `ao_receber()` faz o máximo posição a posição antes de incrementar. Os métodos usam um `Lock` e devolvem uma cópia do vetor, para que o valor registrado no log não mude depois. O registro de eventos passou a gravar `timestampVetorial` no lugar de `timestampLamport`.

### 1. O que acontece com o tamanho do vetor com 10 agências?

Cada mensagem passaria a levar 10 números em vez de 3, porque o vetor tem uma posição por agência. O tamanho cresce de forma linear com a quantidade de processos. Com 10 agências isso não é um problema, pois são poucos bytes perto do resto da mensagem. Passa a ser um problema em sistemas com milhares de processos ou quando processos entram e saem com frequência, porque todos precisam conhecer o tamanho e a ordem do vetor.

### 2. `V1 = [3, 1, 0]` e `V2 = [3, 2, 0]`

O evento de `V1` aconteceu antes. Na posição 0 os valores são iguais (3 e 3), na posição 1 o `V1` é menor (1 e 2) e na posição 2 são iguais (0 e 0). Como `V1[i] <= V2[i]` em todas as posições e os vetores são diferentes, `V1` aconteceu antes de `V2`.

### 3. `V1 = [3, 1, 0]` e `V2 = [1, 3, 0]`

Os eventos são concorrentes. Na posição 0 o `V1` é maior (3 e 1), mas na posição 1 o `V2` é maior (1 e 3). Assim, nem `V1 <= V2` nem `V2 <= V1`. Um evento não conhecia o outro quando aconteceu.

## Parte C — Publish/Subscribe entre agências

### Decisões de implementação

A integração usa a biblioteca `aio-pika`, pois ela é assíncrona e roda no mesmo loop do FastAPI. Assim, não é preciso criar uma thread separada para o consumidor. O consumidor é iniciado no `lifespan` da aplicação. A URL do RabbitMQ é lida da variável `RABBITMQ_URL` ou do arquivo `agencia/.env`, que fica fora do Git por conter usuário e senha.

A topologia segue o roteiro: exchange `iceibank.eventos` do tipo `topic`, uma fila durável por agência (`fila-agencia-<id>`) ligada à routing key `agencia.<id>.creditar`, e mensagens persistentes. A rota `/contas/{id}/creditar-remoto` foi removida. Também foi criado o `inspecionar-filas.py`, que mostra quantas mensagens e consumidores cada fila tem sem expor a URL.

Além do débito e do crédito, a agência registra o evento `TRANSFERENCIA_PUBLICADA` com o vetor de `ao_enviar()`. Assim, a linha do tempo mostra o envio da mensagem. Se a publicação falhar, o débito é estornado e a API retorna HTTP 503.

### 1. O que aconteceu quando a Agência 1 voltou?

Com a Agência 1 fora do ar, a transferência retornou 200 e o `inspecionar-filas.py` mostrou a `fila-agencia-1` com 1 mensagem e 0 consumidores. Quando a agência voltou, a mensagem foi entregue logo após a conexão, e o log registrou `[Vetor [3, 1, 0]] CREDITO_REMOTO_FALHOU` com o motivo `conta não encontrada`. Depois disso, o `/status` mostrou `quantidadeContas: 0`.

A mensagem não sumiu por falha da mensageria. Ela foi guardada e entregue. O crédito não foi aplicado porque as contas ficam em memória, e a conta 1 deixou de existir quando a agência reiniciou. O vetor `[3, 1, 0]` também mostra que o relógio recomeçou do zero.

### 2. O que melhorou em relação ao Sprint 1 e o que continua em aberto?

No Sprint 1, a chamada REST falhava na hora quando a agência de destino estava fora do ar. Agora, a origem publica a mensagem e não depende da disponibilidade do destino, e a mensagem durável espera a agência voltar.

Porém, a mensagem não se perder não significa que o sistema está correto. No teste, a conta 0 foi debitada em R$ 10,00 e a conta 1 não recebeu o crédito. A operação continua sem atomicidade e o estado das contas continua em memória. A resposta 200 agora significa apenas que a mensagem foi publicada. Com as funcionalidades adicionais, a origem passa a saber que o crédito falhou, mas o valor ainda não é devolvido automaticamente. Essa compensação fica para o Sprint 4, com Saga ou 2PC.

### 3. O consumidor sem JWT é um problema de segurança?

Sim. O consumidor confia em qualquer mensagem que chega à fila. No meu ambiente, quem tiver a `RABBITMQ_URL` pode publicar em `agencia.1.creditar` e criar um crédito falso, sem passar pela API e sem token. Hoje a URL fica apenas no `.env` local, mas as três agências usam o mesmo usuário do RabbitMQ.

Para reduzir o risco, cada agência poderia ter um usuário próprio no RabbitMQ, com permissão apenas para as filas e routing keys necessárias. As mensagens também poderiam ser assinadas, por exemplo com JWT ou HMAC, e o consumidor validaria a assinatura e a agência de origem. A conexão já usa TLS (`amqps`), o que protege o tráfego, mas não impede publicações de quem possui a credencial.

## Parte D — Linha do tempo causal

### 1. O que torna confiável a comparação com o relógio vetorial?

O vetor guarda quantos eventos de cada agência eram conhecidos no momento do evento. Ao comparar posição a posição, dá para saber se um evento já conhecia tudo o que o outro conhecia (`ANTES`/`DEPOIS`) ou se cada um conhecia algo que o outro não conhecia (`CONCORRENTES`). O relógio de Lamport junta tudo em um único número e perde essa informação.

### 2. Par concorrente encontrado no teste

O script mostrou `[agencia-0] CRIAR_CONTA ([1, 0, 0])  x  [agencia-2] CRIAR_CONTA ([0, 0, 1])`. Os dois eventos são criações de contas em agências diferentes, sem nenhuma mensagem entre elas. A Agência 2 não conhecia nenhum evento da Agência 0, pois tinha 0 na primeira posição, e a Agência 0 também não conhecia a Agência 2. Por isso, um evento não pode ter causado o outro.

A transferência entre agências não apareceu na lista de concorrentes. O script mostrou `TRANSFERENCIA_PUBLICADA ([3, 0, 0])  ANTES  TRANSFERENCIA_CREDITO_REMOTO ([3, 2, 0])`. Pela hora de parede, o crédito apareceu antes da publicação, porque a agência só grava `TRANSFERENCIA_PUBLICADA` depois da confirmação do RabbitMQ. O relógio vetorial mostrou a ordem causal correta.

### 3. O algoritmo O(n²) seria um problema com milhões de eventos?

Sim. Com um milhão de eventos, seriam cerca de 500 bilhões de comparações. Para escalar, a análise pode comparar apenas eventos relacionados, como os da mesma conta ou do mesmo `idOperacao`. Também pode ser feita em janelas de tempo, de forma incremental conforme os eventos chegam, ou em paralelo por partição.

## Funcionalidade adicional escolhida — Seção 2.1

A funcionalidade escolhida foi a fila de mensagens não processadas (dead-letter queue). Ela foi escolhida porque o teste da Parte C mostrou um crédito que falhava por conta não encontrada e era simplesmente descartado. Agora, as filas das agências são declaradas com `x-dead-letter-exchange: iceibank.mortas`. A mensagem que falha volta para a fila e é tentada até 3 vezes. Na terceira falha, a agência a rejeita sem requeue e o RabbitMQ a encaminha para a `fila-mensagens-mortas`, mantendo o conteúdo original e o cabeçalho `x-death`. Assim, a mensagem fica disponível para análise ou reprocessamento manual. O comando `inspecionar-filas.py --mortas` lista essas mensagens sem retirá-las da fila. A evidência está em `evidencias/sprint2/funcionalidade-adicional.png`.

Além da funcionalidade escolhida, foram implementados outros recursos complementares. A evidência deles está em `evidencias/sprint2/funcionalidades-extras.png`.

### Fila de auditoria

O módulo `src.auditoria` assina a exchange com a routing key `#` e recebe uma cópia de todas as mensagens publicadas por todas as agências. As mensagens são gravadas em `agencia/data/auditoria/auditoria-central.jsonl`. A fila é durável, então as mensagens publicadas com o auditor parado são registradas quando ele voltar.

### Notificação de saldo baixo

Depois de um saque ou de uma transferência, se o saldo ficar abaixo de R$ 50,00, a agência publica um alerta em `agencia.<id>.alerta.saldo-baixo`. Esse tópico é separado do crédito e não chega às filas das agências. A auditoria recebe o alerta e o destaca com `[ALERTA]`. O limite pode ser alterado pela variável `LIMITE_SALDO_BAIXO` e aparece no comando `limites`.

### Confirmação de entrega

Depois de processar um crédito, a agência de destino publica uma confirmação em `agencia.<origem>.confirmacao`, com o status `creditado` ou `falhou`. A agência de origem consome essa mensagem na sua própria fila, atualiza o relógio vetorial e a situação da transferência. A situação pode ser consultada em `GET /transferencias/{idOperacao}` ou com o comando `situacao <id>` no frontend.

Durante os testes, a confirmação chegou a ser consumida antes de a origem terminar de responder a requisição da transferência, porque a origem ainda esperava o ack do RabbitMQ. Para corrigir, os dados da transferência passaram a ser guardados antes da publicação.

## Declaração de uso de IA

Foi utilizada IA (Claude) para apoiar a implementação do Sprint 2, os scripts de captura das evidências e a redação e revisão das respostas.
