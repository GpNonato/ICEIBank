import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'servicos/conectividade.dart';
import 'servicos/contas.dart';
import 'servicos/lideranca.dart';
import 'servicos/sessao.dart';
import 'tema.dart';
import 'telas/login_tela.dart';
import 'telas/principal_tela.dart';

class IceibankApp extends StatelessWidget {
  const IceibankApp({
    super.key,
    required this.config,
    required this.prefs,
    required this.sessao,
    required this.lideranca,
    required this.contas,
    required this.conectividade,
  });

  final Configuracao config;
  final SharedPreferences prefs;
  final Sessao sessao;
  final LiderancaServico lideranca;
  final ContasServico contas;
  final ConectividadeServico conectividade;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICEIBank',
      debugShowCheckedModeBanner: false,
      theme: criarTema(),
      home: ListenableBuilder(
        listenable: sessao,
        builder: (context, _) => sessao.autenticada
            ? PrincipalTela(
                config: config,
                sessao: sessao,
                lideranca: lideranca,
                contas: contas,
                conectividade: conectividade,
              )
            : LoginTela(sessao: sessao, config: config, prefs: prefs),
      ),
    );
  }
}
