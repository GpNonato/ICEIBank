import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config.dart';
import 'api.dart';

class TrocaDeLider {
  TrocaDeLider(this.de, this.para, this.em);

  final int? de;
  final int? para;
  final DateTime em;
}

/// Consulta periódica de GET /bully/lider.
///
/// Usa a agência que respondeu por último; se ela não responder, tenta as outras
/// agências conhecidas antes de desistir. A consulta para enquanto o app está em
/// segundo plano, para não gastar bateria e rede à toa.
class LiderancaServico extends ChangeNotifier with WidgetsBindingObserver {
  LiderancaServico(this.api);

  final Api api;

  int? lider;
  int? agenciaConsultada;
  DateTime? atualizadoEm;
  String? erro;
  bool consultando = false;

  /// Trocas de liderança percebidas pelo app desde que a tela foi aberta.
  final List<TrocaDeLider> trocas = [];

  /// Última troca de uma líder conhecida para outra (ignora a primeira descoberta).
  TrocaDeLider? get ultimaTroca {
    for (final troca in trocas.reversed) {
      if (troca.de != null && troca.para != null) return troca;
    }
    return null;
  }

  int _preferida = 0;
  Timer? _timer;
  bool _ativo = false;

  void iniciar() {
    if (_ativo) return;
    _ativo = true;
    WidgetsBinding.instance.addObserver(this);
    _agendar();
    consultar();
  }

  void parar() {
    _ativo = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _agendar() {
    _timer?.cancel();
    _timer = Timer.periodic(Configuracao.intervaloLideranca, (_) => consultar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ativo) return;
    if (state == AppLifecycleState.resumed) {
      _agendar();
      consultar();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  Future<void> consultar() async {
    if (consultando) return;
    consultando = true;
    notifyListeners();

    final ordem = [
      for (var i = 0; i < Configuracao.numeroAgencias; i++) (_preferida + i) % Configuracao.numeroAgencias,
    ];
    int? respondeu;
    int? novoLider;
    for (final agencia in ordem) {
      try {
        final dados = await api.get(agencia, '/bully/lider', timeout: Configuracao.timeoutLideranca);
        novoLider = (dados['liderAtual'] as num?)?.toInt();
        respondeu = agencia;
        break;
      } on SemConexao {
        continue; // tenta a próxima agência
      } on ApiErro {
        continue;
      }
    }

    consultando = false;
    if (respondeu == null) {
      erro = 'Nenhuma das 3 agências respondeu.';
      agenciaConsultada = null;
      notifyListeners();
      return;
    }

    _preferida = respondeu;
    agenciaConsultada = respondeu;
    erro = null;
    atualizadoEm = DateTime.now();
    if (novoLider != lider) {
      trocas.add(TrocaDeLider(lider, novoLider, atualizadoEm!));
      lider = novoLider;
    }
    notifyListeners();
  }
}
