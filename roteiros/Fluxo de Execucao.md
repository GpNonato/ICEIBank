# Comunicação indireta: Mensageria, Pub/Sub e Relógio Vetorial

## Atividade de recapitulação do sistema desenvolvido

### 1. Arquitetura atual e divisão em agências

Como a aplicação está distribuída atualmente? Identifique os processos,
serviços ou componentes envolvidos, as agências existentes e a
responsabilidade de cada um. Explique como uma conta é associada a uma
agência e quais operações são realizadas localmente ou dependem de outra
agência.

**Direcionamento:** identificar os participantes e as fronteiras de
comunicação que serão utilizadas na próxima implementação.

### 2. Comunicação atual entre as agências

Como uma agência se comunica atualmente com outra agência ou serviço?
Descreva o mecanismo utilizado, o fluxo de uma requisição e as respostas
esperadas. O que acontece quando o componente destinatário está
indisponível, demora para responder ou não recebe a mensagem?

**Direcionamento:** reconhecer as limitações da comunicação direta e os
motivos para introduzir comunicação indireta.

### 3. Operações distribuídas e seus efeitos

Escolha uma operação do banco que envolva mais de uma agência, como uma
transferência entre contas de agências distintas. Descreva passo a passo
quais componentes participam, quais dados são alterados e em que
momentos a operação é considerada concluída.

**Direcionamento:** identificar os eventos distribuídos que precisarão
ser comunicados por mensagens.

### 4. Eventos que precisam ser comunicados

Quais eventos relevantes do sistema atual poderiam ser publicados para
que outras partes da aplicação fossem notificadas sem uma chamada
direta? Escolha pelo menos dois eventos, descreva seus dados e indique
quais componentes poderiam produzi-los e consumi-los.

**Direcionamento:** preparar a identificação de tópicos, mensagens e
participantes do modelo Pub/Sub.

### 5. Mensageria e comunicação indireta

Considerando uma transferência entre agências, como o fluxo poderia ser
implementado utilizando um sistema de mensageria ou Pub/Sub, em vez de
uma comunicação direta entre os serviços? Identifique o produtor, o
canal ou tópico, os consumidores e o conteúdo das mensagens.

**Direcionamento:** projetar a primeira versão do fluxo de comunicação
indireta.

### 6. Entrega, duplicidade e processamento de mensagens

Se uma mensagem de transferência for entregue mais de uma vez, ou se for
recebida fora da ordem esperada, quais problemas poderiam ocorrer no
sistema atual? Analise pelo menos um cenário de duplicidade e um cenário
de falha ou reprocessamento. Que informações seriam necessárias para
processar uma mensagem com segurança?

**Direcionamento:** antecipar idempotência, identificação de mensagens e
tratamento de falhas na mensageria.

### 7. Eventos concorrentes e ordenação causal

Considere duas agências executando operações simultaneamente, com troca
de mensagens entre elas. Apresente um cenário em que a ordem de
recebimento das mensagens seja diferente da ordem em que os eventos
ocorreram. Quais consequências essa situação pode trazer para a
interpretação dos eventos do banco?

**Direcionamento:** identificar a necessidade de distinguir ordem local,
ordem de recebimento e relação causal.

### 8. Relógio vetorial na aplicação

Como o relógio vetorial poderia ser associado aos eventos e às mensagens
do sistema distribuído? Defina quais processos ou agências participariam
do vetor, em quais momentos ele seria atualizado e como seria utilizado
para comparar dois eventos. Utilize um exemplo de dois eventos
concorrentes e dois eventos causalmente relacionados.

**Direcionamento:** transformar o conceito teórico de relógio vetorial
em um mecanismo integrado à aplicação.

### 9. Consistência e observabilidade dos eventos

Como seria possível verificar, na aplicação, se uma mensagem foi
produzida antes ou depois de outra, se dois eventos são concorrentes e
se uma agência recebeu informações causadas por eventos de outra
agência? Identifique quais dados, logs ou metadados deveriam ser
registrados para permitir essa análise.

**Direcionamento:** preparar a instrumentação e os experimentos de
ordenação causal da próxima versão.

### 10. Proposta de evolução para a próxima implementação

Com base nos problemas identificados, proponha como o sistema poderia
evoluir para utilizar comunicação indireta com mensageria ou Pub/Sub e
relógios vetoriais. Descreva uma operação que será modificada, quais
componentes serão envolvidos, quais mensagens serão trocadas, quais
metadados serão adicionados e como será possível demonstrar que a nova
implementação funciona corretamente.

**Direcionamento:** consolidar a recapitulação em uma proposta concreta
de implementação e experimentação.

## Sugestão de entrega

Para cada pergunta, deve ser respondido com base no código e na
execução do sistema que desenvolveram, apresentando diagramas, exemplos
de mensagens ou trechos de implementação quando forem úteis.
