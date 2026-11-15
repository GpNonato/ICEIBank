import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../servicos/contas.dart';

/// Armazenamento local (SQLite): última cópia de cada conta consultada e a fila de
/// operações feitas no app, inclusive as que ainda aguardam sincronização.
class BancoLocal {
  BancoLocal._(this._db);

  final Database _db;

  static Future<BancoLocal> abrir() async {
    final caminho = join(await getDatabasesPath(), 'iceibank.db');
    final db = await openDatabase(
      caminho,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE contas (
            id INTEGER PRIMARY KEY,
            nomeAluno TEXT NOT NULL,
            saldo REAL NOT NULL,
            vetor TEXT NOT NULL,
            atualizadaEm INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE operacoes (
            id TEXT PRIMARY KEY,
            conta INTEGER NOT NULL,
            tipo TEXT NOT NULL,
            valor REAL NOT NULL,
            destino INTEGER,
            criadaEm INTEGER NOT NULL,
            status TEXT NOT NULL,
            mensagem TEXT,
            vetorConhecido TEXT,
            saldoBase REAL,
            offline INTEGER NOT NULL DEFAULT 0,
            resolvidaEm INTEGER
          )''');
      },
    );
    return BancoLocal._(db);
  }

  Future<void> salvarConta(Conta conta) => _db.insert(
        'contas',
        {
          'id': conta.id,
          'nomeAluno': conta.nomeAluno,
          'saldo': conta.saldo,
          'vetor': jsonEncode(conta.vetor),
          'atualizadaEm': conta.atualizadaEm.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Conta?> lerConta(int id) async {
    final linhas = await _db.query('contas', where: 'id = ?', whereArgs: [id]);
    if (linhas.isEmpty) return null;
    final l = linhas.first;
    return Conta(
      id: l['id'] as int,
      nomeAluno: l['nomeAluno'] as String,
      saldo: (l['saldo'] as num).toDouble(),
      vetor: [for (final v in jsonDecode(l['vetor'] as String) as List) (v as num).toInt()],
      atualizadaEm: DateTime.fromMillisecondsSinceEpoch(l['atualizadaEm'] as int),
      doCache: true,
    );
  }

  Future<void> salvarOperacao(Operacao op) => _db.insert(
        'operacoes',
        {
          'id': op.id,
          'conta': op.conta,
          'tipo': op.tipo.name,
          'valor': op.valor,
          'destino': op.destino,
          'criadaEm': op.criadaEm.millisecondsSinceEpoch,
          'status': op.status,
          'mensagem': op.mensagem,
          'vetorConhecido': op.vetorConhecido == null ? null : jsonEncode(op.vetorConhecido),
          'saldoBase': op.saldoBase,
          'offline': op.offline ? 1 : 0,
          'resolvidaEm': op.resolvidaEm?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Operacao>> listarOperacoes({int limite = 50}) async {
    final linhas = await _db.query('operacoes', orderBy: 'criadaEm DESC', limit: limite);
    return [
      for (final l in linhas)
        Operacao(
          id: l['id'] as String,
          conta: l['conta'] as int,
          tipo: TipoOperacao.values.byName(l['tipo'] as String),
          valor: (l['valor'] as num).toDouble(),
          destino: l['destino'] as int?,
          criadaEm: DateTime.fromMillisecondsSinceEpoch(l['criadaEm'] as int),
          status: l['status'] as String,
          mensagem: l['mensagem'] as String?,
          vetorConhecido: l['vetorConhecido'] == null
              ? null
              : [for (final v in jsonDecode(l['vetorConhecido'] as String) as List) (v as num).toInt()],
          saldoBase: (l['saldoBase'] as num?)?.toDouble(),
          offline: (l['offline'] as int) == 1,
          resolvidaEm: l['resolvidaEm'] == null ? null : DateTime.fromMillisecondsSinceEpoch(l['resolvidaEm'] as int),
        ),
    ];
  }
}
