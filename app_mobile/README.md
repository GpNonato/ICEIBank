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

## Estrutura

- `lib/servicos/api.dart`: chamadas HTTP com o token JWT e tratamento de erros da API;
- `lib/servicos/sessao.dart`: login e token salvo no aparelho;
- `lib/servicos/lideranca.dart`: consulta periódica da líder, com troca de agência se uma não responder;
- `lib/servicos/contas.dart`: saldo e operações na agência responsável pela conta (conta % 3);
- `lib/telas/`: login, início (saldo, ações rápidas e atividade), agências e perfil.
