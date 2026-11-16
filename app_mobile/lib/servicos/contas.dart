import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../dados/banco_local.dart';
import '../util/formatos.dart';
import 'api.dart';
import 'conectividade.dart';

class Conta {
  Conta({
    required this.id,
    required this.nomeAluno,
    required this.saldo,
    required this.vetor,
    required this.atualizadaEm,
    this.doCache = false,
  });

  factory Conta.daApi(Map<String, dynamic> dados) => Conta(
        id: (dados['id'] as num).toInt(),
        nomeAluno: dados['nomeAluno'] as String,
        saldo: (dados['saldo'] as num).toDouble(),
        vetor: [for (final v in (dados['vetorAtual'] as List? ?? const [])) (v as num).toInt()],
        atualizadaEm: DateTime.now(),
      );

  final int id;
  final String nomeAluno;

  /// Saldo confirmado pela agência (na última leitura ou sincronização).
  final double saldo;

  /// Relógio vetorial da agência no momento dessa leitura.
  final List<int> vetor;
  final DateTime atualizadaEm;

  /// true quando a agência não respondeu e os dados vieram do armazenamento local.
  final bool doCache;

  int get agencia => Configuracao.agenciaResponsavel(id);
}

enum TipoOperacao {
  deposito('DEPOSITO'),
  saque('SAQUE'),
  transferencia('TRANSFERENCIA');

  const TipoOperacao(this.codigo);
  final String codigo;
}

/// Operação feita pelo app. As feitas sem conexão ficam na fila até sincronizar.
class Operacao {
  Operacao({
    required this.id,
    required this.conta,
    required this.tipo,
    required this.valor,
    this.destino,
    required this.criadaEm,
    required this.status,
    this.mensagem,
    this.vetorConhecido,
    this.saldoBase,
    this.offline = false,
    this.resolvidaEm,
  });

  final String id;
  final int conta;
  final TipoOperacao tipo;
  final double valor;
  final int? destino;
  final DateTime criadaEm;

  /// concluida | recusada | pendente | sincronizando | sincronizada | conflito | descartada
  String status;
  String? mensagem;

  /// Vetor da agência que o app conhecia quando a operação foi feita offline.
  List<int>? vetorConhecido;

  /// Saldo (provisório) da conta logo antes desta operação.
  double? saldoBase;
  final bool offline;
  DateTime? resolvidaEm;

  bool get credito => tipo == TipoOperacao.deposito;
  bool get aguardando => status == 'pendente' || status == 'sincronizando';
  bool get emAberto => aguardando || status == 'conflito';

  /// Efeito no saldo da conta de origem.
  double get efeito => credito ? valor : -valor;

  String get descricao => switch (tipo) {
        TipoOperacao.deposito => 'Depósito de ${dinheiro(valor)}',
        TipoOperacao.saque => 'Saque de ${dinheiro(valor)}',
        TipoOperacao.transferencia => 'Transferência de ${dinheiro(valor)} para a conta $destino',
      };
}

class OperacaoInvalida implements Exception {
  OperacaoInvalida(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Saldo e operações da conta selecionada, com modo offline-first:
/// - toda consulta bem-sucedida fica salva no SQLite (saldo + vetor da agência);
/// - sem conexão, a consulta mostra o último dado salvo;
/// - operações feitas sem conexão vão para a fila e são sincronizadas sozinhas
///   quando a rede (ou a agência) volta, pelo endpoint /contas/{id}/sincronizar.
class ContasServico extends ChangeNotifier {
  ContasServico(this.api, this.banco, this.conectividade, this.prefs);

  final Api api;
  final BancoLocal banco;
  final ConectividadeServico conectividade;
  final SharedPreferences prefs;

  Conta? conta;
  List<Operacao> operacoes = [];
  bool sincronizando = false;

  /// Conflitos (HTTP 409) que ainda não foram mostrados à pessoa usuária.
  final List<Operacao> conflitosNovos = [];

  Timer? _timer;

  Future<void> iniciar() async {
    operacoes = await banco.listarOperacoes();
    final ultima = prefs.getInt('contaSelecionada');
    if (ultima != null) conta = await banco.lerConta(ultima);
    conectividade.aoReconectar = () => Future.delayed(const Duration(seconds: 1), sincronizar);
    // Também tenta de tempos em tempos: a agência pode ter voltado sem a rede do
    // aparelho mudar.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (conectividade.online && pendentes.isNotEmpty) sincronizar();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Operacao> get pendentes =>
      operacoes.where((o) => o.aguardando).toList()..sort((a, b) => a.criadaEm.compareTo(b.criadaEm));

  List<Operacao> pendentesDa(int idConta) => pendentes.where((o) => o.conta == idConta).toList();

  /// Saldo confirmado + efeito das operações que ainda aguardam sincronização (UI otimista).
  double saldoProvisorio(Conta c) =>
      c.saldo + pendentesDa(c.id).fold<double>(0, (soma, op) => soma + op.efeito);

  Future<Conta> consultar(int id) async {
    final agencia = Configuracao.agenciaResponsavel(id);
    try {
      final dados = await api.get(agencia, '/contas/$id');
      conta = Conta.daApi(dados);
      await banco.salvarConta(conta!);
    } on SemConexao {
      final salva = await banco.lerConta(id);
      if (salva == null) rethrow;
      conta = salva;
    }
    await prefs.setInt('contaSelecionada', id);
    notifyListeners();
    return conta!;
  }

  Future<String> depositar(double valor) => _operar(TipoOperacao.deposito, valor, null);

  Future<String> sacar(double valor) => _operar(TipoOperacao.saque, valor, null);

  Future<String> transferir(int destino, double valor) => _operar(TipoOperacao.transferencia, valor, destino);

  Future<String> _operar(TipoOperacao tipo, double valor, int? destino) async {
    final atual = conta!;
    if (!conectividade.online) return _enfileirar(tipo, valor, destino, 'o aparelho está sem conexão');

    final operacao = Operacao(
      id: gerarIdOperacao(),
      conta: atual.id,
      tipo: tipo,
      valor: valor,
      destino: destino,
      criadaEm: DateTime.now(),
      status: 'concluida',
    );
    try {
      final mensagem = await _chamarOnline(atual, operacao);
      operacao.mensagem = mensagem;
      await _registrar(operacao);
      await consultar(atual.id);
      return mensagem;
    } on SemConexao {
      return _enfileirar(tipo, valor, destino, 'a agência ${atual.agencia} não respondeu');
    } on ApiErro catch (erro) {
      operacao
        ..status = 'recusada'
        ..mensagem = '${erro.mensagem} (HTTP ${erro.status})';
      await _registrar(operacao);
      rethrow;
    }
  }

  Future<String> _chamarOnline(Conta c, Operacao op) async {
    switch (op.tipo) {
      case TipoOperacao.deposito:
        await api.post(c.agencia, '/contas/${c.id}/depositar', {'valor': op.valor});
        return 'Depósito de ${dinheiro(op.valor)} realizado.';
      case TipoOperacao.saque:
        await api.post(c.agencia, '/contas/${c.id}/sacar', {'valor': op.valor});
        return 'Saque de ${dinheiro(op.valor)} realizado.';
      case TipoOperacao.transferencia:
        final resposta = await api.post(c.agencia, '/transferencias', {
          'idOrigem': c.id,
          'idDestino': op.destino,
          'valor': op.valor,
          'idOperacao': op.id,
        });
        return resposta['mensagem'] as String? ?? 'Transferência enviada.';
    }
  }

  Future<String> _enfileirar(TipoOperacao tipo, double valor, int? destino, String motivo) async {
    final atual = conta!;
    if (atual.vetor.isEmpty) {
      throw OperacaoInvalida('Consulte o saldo com conexão antes de operar offline.');
    }
    final base = saldoProvisorio(atual);
    if (tipo != TipoOperacao.deposito && valor > base) {
      throw OperacaoInvalida('Saldo provisório insuficiente (${dinheiro(base)}) para operar offline.');
    }
    final operacao = Operacao(
      id: gerarIdOperacao(),
      conta: atual.id,
      tipo: tipo,
      valor: valor,
      destino: destino,
      criadaEm: DateTime.now(),
      status: 'pendente',
      mensagem: 'Aguardando conexão com a agência ${atual.agencia}',
      vetorConhecido: List.of(atual.vetor),
      saldoBase: base,
      offline: true,
    );
    await _registrar(operacao);
    return 'Operação guardada no aparelho: $motivo. Ela será sincronizada sozinha quando a conexão voltar.';
  }

  Future<void> _registrar(Operacao op) async {
    operacoes.removeWhere((o) => o.id == op.id);
    operacoes.insert(0, op);
    await banco.salvarOperacao(op);
    notifyListeners();
  }

  Future<void> _salvar(Operacao op) async {
    await banco.salvarOperacao(op);
    notifyListeners();
  }

  /// Envia a fila de pendentes, na ordem em que as operações foram feitas.
  Future<void> sincronizar() async {
    if (sincronizando || api.token == null) return;
    final fila = pendentes;
    if (fila.isEmpty) return;
    sincronizando = true;
    notifyListeners();
    final agenciasForaDoAr = <int>{};
    try {
      for (final op in fila) {
        if (op.status != 'pendente') continue;
        final agencia = Configuracao.agenciaResponsavel(op.conta);
        if (agenciasForaDoAr.contains(agencia)) continue;
        op.status = 'sincronizando';
        notifyListeners();
        try {
          final resposta = await _enviarSincronizacao(op, op.vetorConhecido!);
          await _aplicarSucesso(op, resposta, 'Sincronizada às ${hora(DateTime.now())}');
        } on ApiErro catch (erro) {
          if (erro.status == 409) {
            await _tratarConflito(op, erro.corpo);
          } else if (erro.status == 401) {
            op.status = 'pendente';
            await _salvar(op);
            break; // sessão expirada: continua na fila até um novo login
          } else {
            op
              ..status = 'recusada'
              ..mensagem = '${erro.mensagem} (HTTP ${erro.status})'
              ..resolvidaEm = DateTime.now();
            await _salvar(op);
          }
        } on SemConexao {
          op.status = 'pendente';
          agenciasForaDoAr.add(agencia);
          await _salvar(op);
        }
      }
    } finally {
      sincronizando = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _enviarSincronizacao(Operacao op, List<int> vetor) {
    return api.post(Configuracao.agenciaResponsavel(op.conta), '/contas/${op.conta}/sincronizar', {
      'tipo': op.tipo.codigo,
      'valor': op.valor,
      'vetorConhecido': vetor,
      'idOperacao': op.id,
      if (op.destino != null) 'idDestino': op.destino,
    });
  }

  Future<void> _atualizarCache(Map<String, dynamic> dadosConta, List<int> vetor) async {
    final real = Conta(
      id: (dadosConta['id'] as num).toInt(),
      nomeAluno: dadosConta['nomeAluno'] as String,
      saldo: (dadosConta['saldo'] as num).toDouble(),
      vetor: vetor,
      atualizadaEm: DateTime.now(),
    );
    await banco.salvarConta(real);
    if (conta?.id == real.id) conta = real;
  }

  List<int> _vetor(Object? lista) => [for (final v in (lista as List)) (v as num).toInt()];

  Future<void> _aplicarSucesso(Operacao op, Map<String, dynamic> resposta, String mensagem) async {
    final vetorAnterior = op.vetorConhecido;
    final novoVetor = _vetor(resposta['vetorAtual']);
    op
      ..status = 'sincronizada'
      ..mensagem = mensagem
      ..resolvidaEm = DateTime.now();
    await _atualizarCache(resposta, novoVetor);
    // As próximas pendentes da mesma agência, feitas a partir do mesmo vetor, passam
    // a usar o vetor devolvido: a única mudança foi a própria operação do app.
    for (final outra in pendentes) {
      if (outra.status == 'pendente' &&
          Configuracao.agenciaResponsavel(outra.conta) == Configuracao.agenciaResponsavel(op.conta) &&
          listEquals(outra.vetorConhecido, vetorAnterior)) {
        outra.vetorConhecido = novoVetor;
        await banco.salvarOperacao(outra);
      }
    }
    await _salvar(op);
  }

  Future<void> _tratarConflito(Operacao op, Map<String, dynamic> corpo) async {
    final contaAtual = corpo['contaAtual'] as Map<String, dynamic>;
    final vetorAtual = _vetor(corpo['vetorAtual']);
    final saldoReal = (contaAtual['saldo'] as num).toDouble();
    await _atualizarCache(contaAtual, vetorAtual);

    // O vetor é da agência inteira: ele também avança com operações de outras contas
    // e com a eleição de líder. Se o saldo desta conta é o mesmo que o app esperava,
    // a conta não mudou e a operação é reaplicada uma vez com o vetor atual.
    final base = op.saldoBase;
    if (base != null && (saldoReal - base).abs() < 0.005) {
      try {
        final resposta = await _enviarSincronizacao(op, vetorAtual);
        await _aplicarSucesso(op, resposta, 'Reaplicada após conflito (o saldo da conta não tinha mudado)');
        return;
      } on ApiErro catch (erro) {
        if (erro.status != 409) {
          op
            ..status = 'recusada'
            ..mensagem = '${erro.mensagem} (HTTP ${erro.status})'
            ..resolvidaEm = DateTime.now();
          await _salvar(op);
          return;
        }
      }
    }

    op
      ..status = 'conflito'
      ..mensagem = 'Não aplicada: o saldo mudou na agência enquanto o app estava offline '
          '(esperado ${dinheiro(base ?? 0)}, real ${dinheiro(saldoReal)}).';
    conflitosNovos.add(op);
    await _salvar(op);
  }

  /// Decisão da pessoa usuária depois de um conflito: aplicar sobre o saldo atual.
  Future<void> reenviar(Operacao op) async {
    final atual = await banco.lerConta(op.conta);
    if (atual == null) return;
    final base = saldoProvisorio(atual); // calculado antes de a operação voltar para a fila
    op
      ..status = 'pendente'
      ..vetorConhecido = atual.vetor
      ..saldoBase = base
      ..mensagem = 'Reenviada pela pessoa usuária sobre o saldo atual';
    await _salvar(op);
    await sincronizar();
  }

  Future<void> descartar(Operacao op) async {
    op
      ..status = 'descartada'
      ..mensagem = 'Descartada pela pessoa usuária após o conflito'
      ..resolvidaEm = DateTime.now();
    await _salvar(op);
  }

  void limpar() {
    conta = null;
    prefs.remove('contaSelecionada');
    notifyListeners();
  }
}
