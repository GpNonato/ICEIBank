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

/// Definição de líder registrada por uma agência (GET /bully/historico).
class RegistroLider {
  RegistroLider({required this.lider, required this.em, required this.motivo, required this.mudou});

  factory RegistroLider.daApi(Map<String, dynamic> dados) => RegistroLider(
        lider: (dados['liderAtual'] as num?)?.toInt(),
        em: DateTime.parse(dados['horaParede'] as String).toLocal(),
        motivo: dados['motivo'] as String? ?? '',
        mudou: dados['mudou'] as bool? ?? false,
      );

  final int? lider;
  final DateTime em;
  final String motivo;
  final bool mudou;
}

/// Resultado da última consulta a uma agência.
class EstadoAgencia {
  EstadoAgencia({required this.id, required this.online, this.lider, this.latenciaMs, required this.verificadaEm});

  final int id;
  final bool online;

  /// Quem esta agência considera a líder.
  final int? lider;
  final int? latenciaMs;
  final DateTime verificadaEm;
}

/// Consulta periódica de GET /bully/lider nas 3 agências, em paralelo.
///
/// A líder exibida é a informada pela agência que respondeu por último; se ela não
/// responder, vale a resposta da próxima agência conhecida. Como todas são
/// consultadas, o app também sabe quais agências estão ativas e percebe quando elas
/// ainda divergem sobre a líder (eleição em andamento). A consulta para enquanto o
/// app está em segundo plano, para não gastar bateria e rede à toa.
class LiderancaServico extends ChangeNotifier with WidgetsBindingObserver {
  LiderancaServico(this.api);

  final Api api;

  int? lider;
  int? agenciaConsultada;
  DateTime? atualizadoEm;
  String? erro;
  bool consultando = false;

  /// Estado de cada agência na última consulta (indicador de agências ativas).
  final Map<int, EstadoAgencia> agencias = {};

  /// Trocas de liderança percebidas pelo app desde que a tela foi aberta.
  final List<TrocaDeLider> trocas = [];

  /// Histórico de líderes da agência consultada (só é buscado com a aba Agências aberta).
  List<RegistroLider> historico = [];
  int? historicoDe;
  bool _detalhado = false;

  set detalhado(bool valor) {
    if (valor == _detalhado) return;
    _detalhado = valor;
    if (valor) consultar();
  }

  /// Última troca de uma líder conhecida para outra (ignora a primeira descoberta).
  TrocaDeLider? get ultimaTroca {
    for (final troca in trocas.reversed) {
      if (troca.de != null && troca.para != null) return troca;
    }
    return null;
  }

  int get ativas => agencias.values.where((a) => a.online).length;

  /// As agências que responderam não concordam sobre a líder.
  bool get divergencia => agencias.values.where((a) => a.online).map((a) => a.lider).toSet().length > 1;

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

  Future<EstadoAgencia> _consultarAgencia(int agencia) async {
    final inicio = DateTime.now();
    try {
      final dados = await api.get(agencia, '/bully/lider', timeout: Configuracao.timeoutLideranca);
      return EstadoAgencia(
        id: agencia,
        online: true,
        lider: (dados['liderAtual'] as num?)?.toInt(),
        latenciaMs: DateTime.now().difference(inicio).inMilliseconds,
        verificadaEm: DateTime.now(),
      );
    } on SemConexao {
      return EstadoAgencia(id: agencia, online: false, verificadaEm: DateTime.now());
    } on ApiErro {
      return EstadoAgencia(id: agencia, online: false, verificadaEm: DateTime.now());
    }
  }

  /// Eleição sob demanda na agência consultada (POST /bully/eleicao/forcar).
  Future<String> forcarEleicao() async {
    final agencia = agenciaConsultada ?? _preferida;
    final dados = await api.post(agencia, '/bully/eleicao/forcar', const {});
    // dá tempo para as mensagens de eleição e de coordenador circularem
    Future.delayed(const Duration(milliseconds: 2500), consultar);
    return dados['mensagem'] as String? ?? 'Eleição iniciada na Agência $agencia.';
  }

  Future<void> _buscarHistorico(int agencia) async {
    try {
      final dados = await api.get(agencia, '/bully/historico', timeout: Configuracao.timeoutLideranca);
      historico = [
        for (final item in dados['historico'] as List) RegistroLider.daApi(item as Map<String, dynamic>),
      ];
      historicoDe = agencia;
    } on SemConexao {
      // mantém o último histórico conhecido
    } on ApiErro {
      // idem
    }
  }

  Future<void> consultar() async {
    if (consultando) return;
    consultando = true;
    notifyListeners();

    final resultados = await Future.wait([
      for (var i = 0; i < Configuracao.numeroAgencias; i++) _consultarAgencia(i),
    ]);
    for (final r in resultados) {
      agencias[r.id] = r;
    }

    consultando = false;
    // agência preferida primeiro; se ela não respondeu, a próxima conhecida
    final ordem = [
      for (var i = 0; i < Configuracao.numeroAgencias; i++) (_preferida + i) % Configuracao.numeroAgencias,
    ];
    final respondeu = ordem.where((i) => agencias[i]!.online).firstOrNull;
    if (respondeu == null) {
      erro = 'Nenhuma das 3 agências respondeu.';
      agenciaConsultada = null;
      notifyListeners();
      return;
    }

    final novoLider = agencias[respondeu]!.lider;
    if (_detalhado) await _buscarHistorico(respondeu);
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
