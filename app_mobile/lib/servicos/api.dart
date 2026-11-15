import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Resposta de erro da API (status HTTP + mensagem do campo "erro").
class ApiErro implements Exception {
  ApiErro(this.status, this.mensagem, [this.corpo = const {}]);

  final int status;
  final String mensagem;
  final Map<String, dynamic> corpo;

  @override
  String toString() => mensagem;
}

/// A agência não respondeu (fora do ar, sem rede ou tempo esgotado).
class SemConexao implements Exception {
  SemConexao(this.agencia, this.detalhe);

  final int agencia;
  final String detalhe;

  @override
  String toString() => 'Sem conexão com a agência $agencia ($detalhe).';
}

/// Cliente HTTP das agências: reenvia o JWT em toda chamada protegida.
class Api {
  Api(this.config);

  final Configuracao config;
  final http.Client _cliente = http.Client();

  String? token;

  /// Chamado quando uma rota protegida devolve 401 (token ausente, inválido ou expirado).
  void Function(String mensagem)? aoReceber401;

  Future<Map<String, dynamic>> get(int agencia, String caminho, {Duration? timeout}) =>
      _enviar(agencia, 'GET', caminho, timeout: timeout);

  Future<Map<String, dynamic>> post(
    int agencia,
    String caminho,
    Map<String, dynamic> corpo, {
    Duration? timeout,
    bool autenticar = true,
  }) =>
      _enviar(agencia, 'POST', caminho, corpo: corpo, timeout: timeout, autenticar: autenticar);

  Future<Map<String, dynamic>> _enviar(
    int agencia,
    String metodo,
    String caminho, {
    Map<String, dynamic>? corpo,
    Duration? timeout,
    bool autenticar = true,
  }) async {
    final uri = config.url(agencia, caminho);
    final cabecalhos = <String, String>{
      'Content-Type': 'application/json',
      if (autenticar && token != null) 'Authorization': 'Bearer $token',
    };

    http.Response resposta;
    try {
      final requisicao = metodo == 'GET'
          ? _cliente.get(uri, headers: cabecalhos)
          : _cliente.post(uri, headers: cabecalhos, body: jsonEncode(corpo ?? const {}));
      resposta = await requisicao.timeout(timeout ?? Configuracao.timeoutRequisicao);
    } on TimeoutException {
      throw SemConexao(agencia, 'tempo esgotado');
    } on SocketException catch (erro) {
      throw SemConexao(agencia, erro.osError?.message ?? erro.message);
    } on http.ClientException catch (erro) {
      throw SemConexao(agencia, erro.message);
    }

    final texto = utf8.decode(resposta.bodyBytes);
    final dados = texto.isEmpty ? const <String, dynamic>{} : jsonDecode(texto);
    final mapa = dados is Map<String, dynamic> ? dados : <String, dynamic>{'dados': dados};
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return mapa;

    final erro = mapa['erro'];
    final mensagem = erro is String
        ? erro
        : resposta.statusCode == 422
            ? 'Dados inválidos para esta operação.'
            : 'Erro HTTP ${resposta.statusCode}.';
    if (resposta.statusCode == 401 && autenticar) aoReceber401?.call(mensagem);
    throw ApiErro(resposta.statusCode, mensagem, mapa);
  }
}
