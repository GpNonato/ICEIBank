from fastapi import APIRouter, Depends

from .controllers import authController, contasController, extrasController, transferenciasController
from .services import authService

router = APIRouter()
protecao_usuario = [Depends(authService.validar_token_usuario)]
protecao_agencia = [Depends(authService.validar_token_agencia)]

router.add_api_route("/auth/login", authController.login, methods=["POST"])
router.add_api_route(
    "/status", extrasController.consultar_status,
    methods=["GET"], dependencies=protecao_usuario,
)
router.add_api_route(
    "/contas", contasController.criar_conta,
    methods=["POST"], status_code=201, dependencies=protecao_usuario,
)
router.add_api_route(
    "/contas/{id_conta}", contasController.consultar_saldo,
    methods=["GET"], dependencies=protecao_usuario,
)
router.add_api_route(
    "/contas/{id_conta}/depositar", contasController.depositar,
    methods=["POST"], dependencies=protecao_usuario,
)
router.add_api_route(
    "/contas/{id_conta}/sacar", contasController.sacar,
    methods=["POST"], dependencies=protecao_usuario,
)
router.add_api_route(
    "/transferencias", transferenciasController.transferir,
    methods=["POST"], dependencies=protecao_usuario,
)
router.add_api_route(
    "/contas/{id_conta}/creditar-remoto",
    transferenciasController.creditar_remoto,
    methods=["POST"],
    dependencies=protecao_agencia,
)
router.add_api_route(
    "/contas/{id_conta}/historico",
    extrasController.historico_conta,
    methods=["GET"],
    dependencies=protecao_usuario,
)
router.add_api_route(
    "/limites",
    extrasController.consultar_limites,
    methods=["GET"],
    dependencies=protecao_usuario,
)
router.add_api_route(
    "/extratos/consolidado/{nome_aluno}",
    extrasController.extrato_consolidado,
    methods=["GET"],
    dependencies=protecao_usuario,
)
router.add_api_route(
    "/interno/contas",
    extrasController.listar_contas_internas,
    methods=["GET"],
    dependencies=protecao_agencia,
)
