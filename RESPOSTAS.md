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

O relógio vetorial guarda uma posição para cada agência e segue as três regras do roteiro. O registro de eventos passou a gravar o vetor completo no lugar do valor de Lamport.

### 1. O que acontece com o tamanho do vetor com 10 agências?

Cada mensagem passaria a levar 10 números, pois o vetor tem uma posição por agência. Com 10 agências isso não é um problema. Em sistemas com milhares de processos, o vetor fica grande e todos precisam conhecer a quantidade de participantes.

### 2. V1 = [3, 1, 0] e V2 = [3, 2, 0]

V1 aconteceu antes de V2. Todas as posições de V1 são menores ou iguais às de V2, e a segunda posição é menor.

### 3. V1 = [3, 1, 0] e V2 = [1, 3, 0]

Os eventos são concorrentes. V1 é maior na primeira posição e V2 é maior na segunda, então nenhum dos dois vem antes do outro.

## Parte C — Publish/Subscribe entre agências

### Decisões de implementação

A integração usa a biblioteca aio-pika, que é assíncrona e funciona junto com o FastAPI sem precisar de outra thread. A URL do RabbitMQ fica em um arquivo .env, que não vai para o Git porque contém usuário e senha. A rota de crédito remoto do Sprint 1 foi removida.

### 1. O que aconteceu quando a Agência 1 voltou?

Enquanto a Agência 1 estava fora do ar, a mensagem ficou retida na fila. Quando ela voltou, a mensagem foi entregue, mas o log registrou CREDITO_REMOTO_FALHOU porque a conta não existia mais. A mensageria funcionou. O problema é que as contas ficam em memória e foram perdidas no reinício.

### 2. O que melhorou e o que continua em aberto?

A mensagem não se perde mais quando a agência de destino está fora do ar, e a origem não precisa esperar o destino responder. Porém, o débito foi aplicado na origem e o crédito não chegou ao destino. O sistema continua inconsistente, e essa correção fica para o Sprint 4.

### 3. O consumidor sem JWT é um problema de segurança?

Sim. Quem tiver a URL do RabbitMQ consegue publicar uma mensagem de crédito sem passar pela API. Hoje as três agências usam o mesmo usuário, então seria melhor ter um usuário por agência e assinar as mensagens.

## Parte D — Linha do tempo causal

### 1. O que torna confiável a comparação com o relógio vetorial?

O vetor mostra quantos eventos de cada agência eram conhecidos no momento do evento. Comparando posição por posição, dá para saber se um evento veio antes do outro ou se eles são concorrentes. O relógio de Lamport usa só um número e perde essa informação.

### 2. Par concorrente encontrado no teste

O script mostrou como concorrentes a criação da conta na Agência 0, com vetor [1, 0, 0], e a criação da conta na Agência 2, com vetor [0, 0, 1]. Faz sentido, porque as duas agências não trocaram mensagens e uma não sabia do evento da outra. A transferência entre agências não apareceu como concorrente, pois o envio veio antes do crédito.

### 3. O algoritmo O(n²) seria um problema com milhões de eventos?

Sim, porque o número de comparações cresce muito rápido. Uma solução é comparar apenas eventos relacionados, como os da mesma conta ou da mesma operação.

## Funcionalidade adicional escolhida — Seção 2.1

A funcionalidade escolhida foi a fila de mensagens não processadas (dead-letter queue). Ela foi escolhida porque, no teste de resiliência, o crédito para uma conta inexistente era descartado. Agora a mensagem é tentada três vezes e, se continuar falhando, vai para uma fila separada. Assim, ela pode ser analisada depois.

Além da funcionalidade escolhida, foram implementados outros recursos complementares.

### Fila de auditoria

Um consumidor separado recebe uma cópia de todas as mensagens publicadas pelas agências e grava tudo em um log central.

### Notificação de saldo baixo

Quando um saque ou uma transferência deixa a conta com menos de R$ 50,00, a agência publica um alerta em um tópico separado. O limite pode ser alterado por variável de ambiente.

### Confirmação de entrega

Depois de processar o crédito, a agência de destino envia uma confirmação para a agência de origem. A origem passa a saber se o crédito foi aplicado ou se falhou. O comando situacao do frontend mostra essa informação.

## Declaração de uso de IA

Foi utilizada IA para apoiar a implementação do Sprint 2, a captura das evidências e a revisão das respostas.


# Respostas — Sprint 3: ICEIBank

## Parte A — Mensagens de eleição e coordenador

### Decisões de implementação

O algoritmo foi adaptado para Python com httpx e tarefas do asyncio, com timeout de 1 segundo nas chamadas entre agências. A eleição começa logo depois que a agência passa a aceitar conexões.

### 1. Por que o Bully elege o maior ID?

É só uma regra combinada, que garante um único vencedor. Se fosse invertida, a Agência 0 seria a líder, e o resultado continuaria correto, desde que todas usassem a mesma regra.

### 2. Mais de uma agência declarou TORNOU_LIDER. É um bug?

Não. As agências subiram em momentos diferentes: a 0 virou líder sozinha, depois a 1 e por fim a 2, que anunciou o resultado para as outras. Cada uma decidiu com o que via no momento, e todas convergiram para a Agência 2.

### 3. A falta de autenticação em /bully/eleicao é um problema?

Sim. Qualquer um poderia disparar eleições em sequência ou, pela rota de coordenador, anunciar uma líder falsa. Como no Sprint 4 a líder vai coordenar transações, essas rotas deveriam exigir o token de agência.

## Parte B — Heartbeat e failover automático

### 1. Heartbeat de 100 ms ou de 60 segundos

Com 100 ms a queda é percebida rápido, mas a rede fica cheia de consultas e qualquer lentidão vira uma eleição. Com 60 segundos, o sistema pode ficar até um minuto sem líder. No teste, com 3 segundos, a nova líder foi eleita em cerca de 5 segundos.

### 2. A agência que volta retoma a liderança. Isso é desejável?

Nem sempre, pois provoca uma nova troca mesmo com a líder atual funcionando. Se isso acontecer no meio de uma transação coordenada pela líder, os participantes podem ficar sem saber se confirmam ou desfazem.

### 3. E se a rede estiver lenta e passar de 1 segundo?

Uma agência viva seria tratada como fora do ar. Isso causaria eleições desnecessárias e até duas agências se declarando líderes ao mesmo tempo.

## Parte C — Observando a eleição

### 1. Quantas vezes a liderança mudou na subida?

Duas vezes: da Agência 0 para a 1 e da 1 para a 2, em cerca de 4 segundos. O resultado final não muda, mas há custo de mensagens extras, esperas de timeout e um período em que as agências não concordam sobre a líder.

## Parte D — App Flutter

### Decisões de implementação

O app usa o pacote http, guarda o token JWT no aparelho e envia cada operação para a agência número da conta % 3. A líder aparece no topo da tela inicial e é consultada a cada 3 segundos.

### 1. Com que frequência o app consulta /bully/lider?

A cada 3 segundos, o mesmo intervalo do heartbeat. Consultar mais rápido não ajudaria muito, porque a eleição leva alguns segundos, e gastaria mais bateria e dados.

### 2. E se duas agências responderem líderes diferentes?

O app mostra o que a agência consultada respondeu, e a diferença some na consulta seguinte. Como a líder ainda é só informativa, isso não é um problema real.

### 3. O que foi reaproveitado do frontend web?

Foram reaproveitados os endpoints, o envio do token, a saída no 401 e as mensagens de erro da API. No mobile, foi preciso tratar a perda de conexão, guardar os dados no aparelho e pausar as consultas em segundo plano.

## Parte E — Sincronização offline-first no backend

### Decisões de implementação

A consulta de saldo passou a devolver o vetorAtual, e a sincronização aceita depósito, saque e transferência. No teste, a sincronização com o vetor [9, 5, 3] recebeu 409 e foi aplicada ao usar o vetor [10, 5, 3] devolvido no conflito.

### 1. Por que comparar o vetor, e não só o saldo?

O vetor mostra que algo aconteceu na agência mesmo que o saldo volte ao mesmo valor, como um depósito seguido de um saque igual. Comparar só o saldo aceitaria uma operação feita com informação antiga.

### 2. Por que qualquer mudança no vetor vira conflito?

Porque o vetor é da agência inteira e muda com operações de qualquer conta. Para detectar por conta, cada conta precisaria ter sua própria versão.

### 3. O que o app deve fazer com o 409?

Mostrar o saldo real e perguntar à pessoa, já que se trata de dinheiro. O app só reenvia sozinho quando o saldo real é igual ao esperado, pois nesse caso a conta não mudou.

## Parte F — App Flutter offline-first

### Decisões de implementação

O app guarda as contas e as operações no SQLite. Sem conexão, a operação vai para uma fila e é enviada sozinha quando a rede volta.

### 1. Qual biblioteca de armazenamento local foi escolhida?

Foi escolhido o sqflite, porque as contas e a fila de operações se encaixam bem em tabelas. O Hive e o Drift também foram considerados, mas o Hive só guarda chave e valor e o Drift exige geração de código.

### 2. O que aconteceu na tela quando a sincronização foi recusada?

O app mostrou um aviso com o saldo esperado e o saldo real, com as opções Depois, Descartar e Reenviar. A operação ficou marcada como Conflito, para a pessoa decidir o que fazer.

### 3. Que risco a UI otimista traz para um app bancário?

A pessoa pode tomar decisões com um saldo que ainda não foi confirmado. Por isso o saldo provisório aparece em destaque, junto com o saldo confirmado, e as operações pendentes ficam marcadas.

## Funcionalidade adicional escolhida — Seção 2.1

A funcionalidade escolhida foi o indicador de agências ativas no app. Ela foi escolhida porque o painel só mostrava a líder, sem indicar quais agências estavam fora do ar. O app passou a consultar as três agências e mostra quais estão ativas e quem cada uma considera líder. No teste, ao derrubar a Agência 2, o app mostrou "Agências ativas (2 de 3)".

Além da funcionalidade escolhida, foram implementados outros recursos complementares.

### Histórico de líderes

O endpoint GET /bully/historico lista as últimas trocas de líder vistas pela agência, e o app mostra esse histórico na aba Agências.

### Eleição sob demanda

O endpoint POST /bully/eleicao/forcar dispara uma nova eleição. No app, isso é feito pelo botão Forçar nova eleição.

### Timeout configurável

O intervalo do heartbeat e o timeout podem ser alterados pelas variáveis BULLY_HEARTBEAT_MS e BULLY_TIMEOUT_MS.

## Declaração de uso de IA

Foi utilizada IA para apoiar a implementação do Sprint 3, a captura das evidências e a revisão das respostas.
