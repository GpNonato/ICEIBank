import 'package:flutter/foundation.dart';

/// Endereços e tempos usados pelo app.
///
/// As agências usam as portas 4042, 4043 e 4044 (OFFSET 42, igual ao backend).
/// No emulador Android, o endereço 10.0.2.2 aponta para o localhost do computador.
class Configuracao {
  Configuracao({String? host}) : host = host ?? hostPadrao;

  static const int offset = 42;
  static const int portaBase = 4000 + offset;
  static const int numeroAgencias = 3;

  /// Intervalo da consulta periódica a GET /bully/lider.
  static const Duration intervaloLideranca = Duration(seconds: 3);
  static const Duration timeoutLideranca = Duration(seconds: 2);
  static const Duration timeoutRequisicao = Duration(seconds: 5);

  static String get hostPadrao =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';

  String host;

  static int agenciaResponsavel(int idConta) => idConta % numeroAgencias;

  Uri url(int agencia, String caminho) => Uri.parse('http://$host:${portaBase + agencia}$caminho');
}
