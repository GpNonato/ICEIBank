# ICEIBank

API REST distribuída desenvolvida em Python com FastAPI.

## Instalar as dependências

Na pasta `agencia`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## Executar as agências

Abra três terminais na pasta `agencia`. Em cada um, use um ID diferente:

```powershell
$env:AGENCIA_ID=0
.\.venv\Scripts\python.exe -m src.app
```

Use os IDs `0`, `1` e `2`. Com o offset configurado, as agências usam as portas 4042, 4043 e 4044.

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

## Funcionalidades adicionais

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
