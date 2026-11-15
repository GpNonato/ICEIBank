import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'api.dart';

/// Login via JWT. O token fica salvo para as próximas requisições e para reabrir o app.
class Sessao extends ChangeNotifier {
  Sessao(this.api, this.prefs);

  final Api api;
  final SharedPreferences prefs;

  String? usuario;
  DateTime? expiraEm;

  /// Motivo da última saída forçada (ex.: token expirado), exibido na tela de login.
  String? motivoSaida;

  bool get autenticada => api.token != null;

  void restaurar() {
    api.aoReceber401 = (mensagem) => sair('Sessão encerrada pela API (HTTP 401: $mensagem) Entre novamente.');
    final token = prefs.getString('token');
    final expira = prefs.getInt('tokenExpiraEm');
    if (token != null && expira != null && DateTime.now().millisecondsSinceEpoch < expira) {
      api.token = token;
      usuario = prefs.getString('usuario');
      expiraEm = DateTime.fromMillisecondsSinceEpoch(expira);
    }
  }

  /// O mesmo JWT vale nas 3 agências; se uma estiver fora do ar, tenta a próxima.
  Future<void> entrar(String usuario, String senha) async {
    SemConexao? ultimaFalha;
    for (var agencia = 0; agencia < Configuracao.numeroAgencias; agencia++) {
      try {
        final dados = await api.post(
          agencia,
          '/auth/login',
          {'usuario': usuario, 'senha': senha},
          autenticar: false,
        );
        final segundos = (dados['expires_in'] as num?)?.toInt() ?? 900;
        api.token = dados['access_token'] as String;
        this.usuario = usuario;
        expiraEm = DateTime.now().add(Duration(seconds: segundos));
        motivoSaida = null;
        await prefs.setString('token', api.token!);
        await prefs.setString('usuario', usuario);
        await prefs.setInt('tokenExpiraEm', expiraEm!.millisecondsSinceEpoch);
        notifyListeners();
        return;
      } on SemConexao catch (falha) {
        ultimaFalha = falha;
      }
    }
    throw ultimaFalha!;
  }

  void sair([String? motivo]) {
    if (api.token == null && motivo == null) return;
    api.token = null;
    usuario = null;
    expiraEm = null;
    motivoSaida = motivo;
    prefs.remove('token');
    prefs.remove('tokenExpiraEm');
    notifyListeners();
  }
}
