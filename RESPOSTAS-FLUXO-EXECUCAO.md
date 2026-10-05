# Respostas — Comunicação indireta: Mensageria, Pub/Sub e Relógio Vetorial

### 1. Arquitetura atual e divisão em agências

A aplicação tem três agências, e cada uma é um processo separado com suas próprias contas em memória. Uma conta pertence à agência dada pelo resto da divisão do número da conta por três. Criar conta, consultar saldo, depositar, sacar e transferir dentro da mesma agência são operações locais. A transferência para outra agência e o extrato consolidado dependem das outras agências.

### 2. Comunicação atual entre as agências

No Sprint 1, a agência de origem fazia uma chamada REST direta para a agência de destino e esperava a resposta. Se o destino estivesse fora do ar, a chamada falhava e o débito ficava aplicado sem o crédito. Se o destino demorasse, a requisição ficava esperando até o tempo limite.

### 3. Operações distribuídas e seus efeitos

Na transferência entre agências, a agência de origem valida a operação, debita a conta e publica uma mensagem de crédito. A agência de destino consome essa mensagem e credita a conta. Para o cliente, a operação termina quando a mensagem é publicada, mas o valor só chega ao destino quando a mensagem é processada.

### 4. Eventos que precisam ser comunicados

O primeiro evento é o pedido de crédito. Ele é produzido pela agência de origem e consumido pela agência de destino, com a conta, o valor e o identificador da operação. O segundo evento é a confirmação do crédito. Ela é produzida pela agência de destino e consumida pela agência de origem, informando se o crédito foi aplicado.

### 5. Mensageria e comunicação indireta

A agência de origem é o produtor e publica a mensagem em uma exchange do RabbitMQ. Cada agência tem sua própria fila, e a routing key indica a agência de destino. A agência de destino é a consumidora. A mensagem leva a conta, o valor, a agência de origem, o identificador da operação e o relógio vetorial.

### 6. Entrega, duplicidade e processamento de mensagens

Se a mesma mensagem de crédito for entregue duas vezes, a conta pode receber o valor em dobro. Para evitar isso, cada transferência tem um identificador, e a agência ignora créditos repetidos. Se o processamento falhar, a mensagem é tentada de novo e depois vai para uma fila de mensagens não processadas. Para processar com segurança, a mensagem precisa ter um identificador único, a origem e o relógio vetorial.

### 7. Eventos concorrentes e ordenação causal

Nos testes, ao ordenar os eventos pela hora de parede, o crédito apareceu antes da publicação da transferência. Isso aconteceu porque a origem só registrou a publicação depois da resposta do RabbitMQ. Usando a ordem de recebimento ou a hora de parede, alguém poderia concluir que o crédito aconteceu antes do envio.

### 8. Relógio vetorial na aplicação

Cada agência tem uma posição no vetor. Em um evento local, a agência incrementa sua posição. Ao enviar uma mensagem, ela incrementa a posição e envia o vetor junto. Ao receber, ela pega o maior valor de cada posição e incrementa a sua. A criação de contas nas Agências 0 e 2, com vetores [1, 0, 0] e [0, 0, 1], são eventos concorrentes. Já o envio da transferência, com [3, 0, 0], e o crédito no destino, com [3, 2, 0], são causalmente relacionados.

### 9. Consistência e observabilidade dos eventos

Cada evento é registrado com a agência, o tipo, o relógio vetorial, a hora de parede e os detalhes da operação. O script de mesclar logs compara os vetores e mostra quais eventos são concorrentes e quais vieram antes. A fila de auditoria também guarda uma cópia de todas as mensagens publicadas.

### 10. Proposta de evolução para a próxima implementação

A transferência entre agências deixou de usar a chamada REST direta e passou a usar o RabbitMQ. As mensagens levam o relógio vetorial e o identificador da operação. O funcionamento foi demonstrado com uma transferência normal, com a agência de destino fora do ar e com a linha do tempo causal. O próximo passo é guardar as contas de forma persistente e devolver o valor quando o crédito falhar.
