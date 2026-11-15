# ICEIBank — app mobile (Flutter)

Cliente mobile do ICEIBank. Usa a mesma API REST das agências (login com JWT, saldo,
depósito, saque e transferência) e mostra qual agência é a líder atual, consultando
`GET /bully/lider` a cada 3 segundos. Se a agência consultada não responder, o app tenta
as outras duas.

## Executar

Com as 3 agências no ar (portas 4042, 4043 e 4044), na pasta `app_mobile`:

```powershell
flutter pub get
flutter run
```

No emulador Android, o app acessa as agências pelo endereço `10.0.2.2`, que aponta para o
`localhost` do computador. Em um celular físico, toque em "Agências em ..." na tela de
login e informe o IP do computador na rede local.

Credenciais padrão das agências: usuário `gabriel`, senha `iceibank123`.

## Modo offline-first

- Cada conta consultada fica salva no SQLite do aparelho (saldo + `vetorAtual` da agência).
  Sem conexão, a tela mostra o último dado salvo.
- Depósitos, saques e transferências feitos sem conexão (aparelho offline ou agência fora do
  ar) vão para uma fila local, junto com o vetor que o app conhecia. A tela mostra o saldo
  provisório e a operação como "Pendente".
- Quando a rede volta (`connectivity_plus`) ou a agência volta a responder, a fila é enviada
  sozinha para `POST /contas/{id}/sincronizar`, na ordem em que as operações foram feitas.
- Se a agência recusar com HTTP 409, o app atualiza o saldo real e mostra um aviso com as
  opções "Reenviar" (aplicar sobre o saldo atual) e "Descartar". Quando o saldo da conta é o
  mesmo que o app esperava (o vetor avançou por operações de outras contas), a operação é
  reaplicada automaticamente uma vez.

Para testar no emulador:

```powershell
adb shell cmd connectivity airplane-mode enable
adb shell cmd connectivity airplane-mode disable
```

## Estrutura

- `lib/servicos/api.dart`: chamadas HTTP com o token JWT e tratamento de erros da API;
- `lib/servicos/sessao.dart`: login e token salvo no aparelho;
- `lib/servicos/lideranca.dart`: consulta periódica da líder, com troca de agência se uma não responder;
- `lib/servicos/contas.dart`: saldo e operações na agência responsável pela conta (conta % 3),
  fila offline e sincronização;
- `lib/servicos/conectividade.dart`: detecta quando o aparelho fica sem rede e quando ela volta;
- `lib/dados/banco_local.dart`: tabelas `contas` e `operacoes` no SQLite (`sqflite`);
- `lib/telas/`: login, início (saldo, fila offline, ações rápidas e atividade), agências e perfil.
