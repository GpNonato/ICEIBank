import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado da rede do aparelho (Wi-Fi, dados móveis ou nenhuma, como no modo avião).
class ConectividadeServico extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _assinatura;

  bool online = true;

  /// Chamado quando a rede volta depois de ter caído.
  VoidCallback? aoReconectar;

  Future<void> iniciar() async {
    _atualizar(await _connectivity.checkConnectivity(), avisar: false);
    _assinatura = _connectivity.onConnectivityChanged.listen(_atualizar);
  }

  void _atualizar(List<ConnectivityResult> resultados, {bool avisar = true}) {
    final agora = resultados.any((r) => r != ConnectivityResult.none);
    if (agora == online) return;
    online = agora;
    notifyListeners();
    if (online && avisar) aoReconectar?.call();
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    super.dispose();
  }
}
