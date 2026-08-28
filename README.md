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

## Autenticação

O endpoint `POST /auth/login` recebe `usuario` e `senha`. As credenciais locais padrão são:

```text
usuario: gabriel
senha: iceibank123
```

Em outro ambiente, configure `ICEIBANK_USUARIO`, `ICEIBANK_SENHA` e `JWT_SECRET` antes de iniciar as agências. O token expira em 15 minutos por padrão.
