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
