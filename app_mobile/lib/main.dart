import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config.dart';
import 'dados/banco_local.dart';
import 'servicos/api.dart';
import 'servicos/conectividade.dart';
import 'servicos/contas.dart';
import 'servicos/lideranca.dart';
import 'servicos/sessao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final config = Configuracao(host: prefs.getString('host'));
  final api = Api(config);
  final sessao = Sessao(api, prefs)..restaurar();
  final banco = await BancoLocal.abrir();
  final conectividade = ConectividadeServico();
  await conectividade.iniciar();
  final contas = ContasServico(api, banco, conectividade, prefs);
  await contas.iniciar();

  runApp(IceibankApp(
    config: config,
    prefs: prefs,
    sessao: sessao,
    lideranca: LiderancaServico(api),
    contas: contas,
    conectividade: conectividade,
  ));
}
