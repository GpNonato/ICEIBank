from fastapi import APIRouter

from .controllers import contasController, transferenciasController

router = APIRouter()
router.add_api_route("/contas", contasController.criar_conta, methods=["POST"], status_code=201)
router.add_api_route("/contas/{id_conta}", contasController.consultar_saldo, methods=["GET"])
router.add_api_route("/contas/{id_conta}/depositar", contasController.depositar, methods=["POST"])
router.add_api_route("/contas/{id_conta}/sacar", contasController.sacar, methods=["POST"])
router.add_api_route("/transferencias", transferenciasController.transferir, methods=["POST"])
router.add_api_route(
    "/contas/{id_conta}/creditar-remoto",
    transferenciasController.creditar_remoto,
    methods=["POST"],
)
