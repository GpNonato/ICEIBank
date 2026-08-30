import json
import os
from pathlib import Path

import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Request, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .config import AGENCIAS, obter_agencia
from .routes import router
from .services import authService
from .services.eventLog import RegistroEventos
from .services.lamportClock import RelogioLamport


id_agencia = int(os.getenv("AGENCIA_ID", "0"))
agencia_config = obter_agencia(id_agencia)
if agencia_config is None:
    raise RuntimeError(f"Agência {id_agencia} não configurada em config.py")

app = FastAPI(
    title=f"ICEIBank - Agência {id_agencia}",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
app.state.id_agencia = id_agencia
app.state.relogio = RelogioLamport()
app.state.registro = RegistroEventos(f"agencia-{id_agencia}")
app.state.contas = {}
app.state.transferencias_processadas = {}
app.state.creditos_processados = {}

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        f"http://{host}:{agencia['url'].rsplit(':', 1)[1]}"
        for agencia in AGENCIAS
        for host in ("localhost", "127.0.0.1")
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


def esquema_openapi() -> dict:
    esquema = app.openapi()
    esquema["servers"] = [{"url": agencia_config["url"]}]
    return esquema


@app.get(
    "/openapi.json",
    include_in_schema=False,
    dependencies=[Depends(authService.validar_token_usuario)],
)
async def obter_openapi():
    return JSONResponse(esquema_openapi())


@app.get("/docs", include_in_schema=False, response_class=HTMLResponse)
async def obter_documentacao(
    credenciais=Security(authService.esquema_bearer),
):
    await authService.validar_token_usuario(credenciais)
    token = json.dumps(credenciais.credentials)
    esquema = json.dumps(esquema_openapi(), ensure_ascii=False)
    titulo = json.dumps(f"ICEIBank - Agência {id_agencia} - Swagger UI")
    return HTMLResponse(
        f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>{json.loads(titulo)}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
<div id="swagger-ui"></div>
<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
<script>
SwaggerUIBundle({{
  spec: {esquema},
  dom_id: '#swagger-ui',
  deepLinking: true,
  requestInterceptor: function (requisicao) {{
    requisicao.headers.Authorization = 'Bearer ' + {token};
    return requisicao;
  }}
}})
</script>
</body>
</html>"""
    )


@app.exception_handler(HTTPException)
async def tratar_erro_http(_request: Request, erro: HTTPException):
    return JSONResponse(
        status_code=erro.status_code,
        content={"erro": erro.detail},
        headers=erro.headers,
    )


PASTA_FRONTEND = Path(__file__).resolve().parents[2] / "frontend"
if PASTA_FRONTEND.is_dir():
    app.mount("/", StaticFiles(directory=PASTA_FRONTEND, html=True), name="frontend")


if __name__ == "__main__":
    porta = int(agencia_config["url"].rsplit(":", 1)[1])
    print(f"[Agência {id_agencia}] iniciando na porta {porta}", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=porta)
