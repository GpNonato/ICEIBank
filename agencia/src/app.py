import os

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

from .config import obter_agencia
from .routes import router
from .services.eventLog import RegistroEventos
from .services.lamportClock import RelogioLamport


id_agencia = int(os.getenv("AGENCIA_ID", "0"))
agencia_config = obter_agencia(id_agencia)
if agencia_config is None:
    raise RuntimeError(f"Agência {id_agencia} não configurada em config.py")

app = FastAPI(title=f"ICEIBank - Agência {id_agencia}")
app.state.id_agencia = id_agencia
app.state.relogio = RelogioLamport()
app.state.registro = RegistroEventos(f"agencia-{id_agencia}")
app.state.contas = {}
app.include_router(router)


@app.exception_handler(HTTPException)
async def tratar_erro_http(_request: Request, erro: HTTPException):
    return JSONResponse(
        status_code=erro.status_code,
        content={"erro": erro.detail},
        headers=erro.headers,
    )


if __name__ == "__main__":
    porta = int(agencia_config["url"].rsplit(":", 1)[1])
    print(f"[Agência {id_agencia}] iniciando na porta {porta}", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=porta)
