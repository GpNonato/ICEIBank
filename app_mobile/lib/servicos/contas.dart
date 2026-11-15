import 'package:flutter/foundation.dart';

import '../config.dart';
import '../util/formatos.dart';
import 'api.dart';

class Conta {
  Conta({
    required this.id,
    required this.nomeAluno,
    required this.saldo,
    required this.vetor,
    required this.atualizadaEm,
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
  final double saldo;
  final List<int> vetor;
  final DateTime atualizadaEm;

  int get agencia => Configuracao.agenciaResponsavel(id);
}

enum TipoOperacao { deposito, saque, transferencia }

/// Operação feita pelo app (exibida em "Atividade recente").
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
  });

  final String id;
  final int conta;
  final TipoOperacao tipo;
  final double valor;
  final int? destino;
  final DateTime criadaEm;
  String status; // concluida | recusada
  String? mensagem;

  bool get credito => tipo == TipoOperacao.deposito;
}

/// Operações bancárias da conta selecionada, sempre na agência responsável por ela.
class ContasServico extends ChangeNotifier {
  ContasServico(this.api);

  final Api api;

  Conta? conta;
  final List<Operacao> operacoes = [];

  Future<Conta> consultar(int id) async {
    final agencia = Configuracao.agenciaResponsavel(id);
    final dados = await api.get(agencia, '/contas/$id');
    conta = Conta.daApi(dados);
    notifyListeners();
    return conta!;
  }

  Future<String> depositar(double valor) => _operar(TipoOperacao.deposito, valor, null, (c, id) async {
        await api.post(c.agencia, '/contas/${c.id}/depositar', {'valor': valor});
        return 'Depósito de ${dinheiro(valor)} realizado.';
      });

  Future<String> sacar(double valor) => _operar(TipoOperacao.saque, valor, null, (c, id) async {
        await api.post(c.agencia, '/contas/${c.id}/sacar', {'valor': valor});
        return 'Saque de ${dinheiro(valor)} realizado.';
      });

  Future<String> transferir(int destino, double valor) =>
      _operar(TipoOperacao.transferencia, valor, destino, (c, id) async {
        final resposta = await api.post(c.agencia, '/transferencias', {
          'idOrigem': c.id,
          'idDestino': destino,
          'valor': valor,
          'idOperacao': id,
        });
        return resposta['mensagem'] as String? ?? 'Transferência enviada.';
      });

  Future<String> _operar(
    TipoOperacao tipo,
    double valor,
    int? destino,
    Future<String> Function(Conta conta, String idOperacao) chamada,
  ) async {
    final atual = conta!;
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
      final mensagem = await chamada(atual, operacao.id);
      operacao.mensagem = mensagem;
      operacoes.insert(0, operacao);
      await consultar(atual.id);
      return mensagem;
    } on ApiErro catch (erro) {
      operacao
        ..status = 'recusada'
        ..mensagem = '${erro.mensagem} (HTTP ${erro.status})';
      operacoes.insert(0, operacao);
      notifyListeners();
      rethrow;
    }
  }

  void limpar() {
    conta = null;
    notifyListeners();
  }
}
