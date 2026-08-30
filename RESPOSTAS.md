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
