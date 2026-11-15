import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/conectividade.dart';
import '../servicos/contas.dart';
import '../servicos/lideranca.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import '../util/formatos.dart';
import 'agencias_tela.dart';
import 'inicio_tela.dart';
import 'perfil_tela.dart';

/// Estrutura com barra de navegação inferior. Mantém a consulta da líder ativa,
/// avisa quando a liderança muda e quando uma sincronização offline é recusada.
class PrincipalTela extends StatefulWidget {
  const PrincipalTela({
    super.key,
    required this.config,
    required this.sessao,
    required this.lideranca,
    required this.contas,
    required this.conectividade,
  });

  final Configuracao config;
  final Sessao sessao;
  final LiderancaServico lideranca;
  final ContasServico contas;
  final ConectividadeServico conectividade;

  @override
  State<PrincipalTela> createState() => _PrincipalTelaState();
}

class _PrincipalTelaState extends State<PrincipalTela> {
  int _aba = 0;
  late int _trocasVistas;
  bool _dialogoAberto = false;

  @override
  void initState() {
    super.initState();
    _trocasVistas = widget.lideranca.trocas.length;
    widget.lideranca.addListener(_avisarTrocaDeLider);
    widget.contas.addListener(_mostrarConflitos);
    widget.lideranca.iniciar();
    // Pendências de antes do login (ex.: token expirado) são enviadas agora.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.contas.sincronizar());
  }

  @override
  void dispose() {
    widget.lideranca.removeListener(_avisarTrocaDeLider);
    widget.contas.removeListener(_mostrarConflitos);
    widget.lideranca.parar();
    super.dispose();
  }

  void _avisarTrocaDeLider() {
    final trocas = widget.lideranca.trocas;
    while (_trocasVistas < trocas.length) {
      final troca = trocas[_trocasVistas++];
      if (troca.de != null && troca.para != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Cores.primaria,
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Cores.lider),
              const SizedBox(width: 10),
              Expanded(child: Text('Nova líder: Agência ${troca.para} (antes era a Agência ${troca.de}).')),
            ],
          ),
        ));
      }
    }
  }

  /// Conflito (HTTP 409): a operação offline não foi aplicada; a pessoa decide o que fazer.
  Future<void> _mostrarConflitos() async {
    if (_dialogoAberto || !mounted || widget.contas.conflitosNovos.isEmpty) return;
    final op = widget.contas.conflitosNovos.removeAt(0);
    _dialogoAberto = true;
    final saldoReal = widget.contas.conta?.id == op.conta ? widget.contas.conta!.saldo : null;
    final escolha = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(Icons.sync_problem_rounded, color: Cores.debito, size: 36),
        title: const Text('Operação offline não aplicada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${op.descricao} feito às ${hora(op.criadaEm)}, sem conexão, na conta ${op.conta}.'),
            const SizedBox(height: 10),
            const Text(
              'A agência recusou a sincronização (HTTP 409): a conta mudou enquanto o app '
              'estava offline, então a operação não foi aplicada automaticamente.',
            ),
            const SizedBox(height: 10),
            Text('Saldo esperado pelo app: ${dinheiro(op.saldoBase ?? 0)}'),
            if (saldoReal != null)
              Text('Saldo real na agência: ${dinheiro(saldoReal)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'depois'), child: const Text('Depois')),
          TextButton(onPressed: () => Navigator.pop(context, 'descartar'), child: const Text('Descartar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'reenviar'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Reenviar'),
          ),
        ],
      ),
    );
    _dialogoAberto = false;
    if (escolha == 'reenviar') await widget.contas.reenviar(op);
    if (escolha == 'descartar') await widget.contas.descartar(op);
    if (widget.contas.conflitosNovos.isNotEmpty) await _mostrarConflitos();
  }

  void _sair() {
    widget.contas.limpar();
    widget.sessao.sair();
  }

  @override
  Widget build(BuildContext context) {
    final abas = [
      InicioTela(
        sessao: widget.sessao,
        lideranca: widget.lideranca,
        contas: widget.contas,
        conectividade: widget.conectividade,
        aoAbrirAgencias: () => setState(() => _aba = 1),
      ),
      AgenciasTela(lideranca: widget.lideranca),
      PerfilTela(sessao: widget.sessao, config: widget.config, aoSair: _sair),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _aba, children: abas)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (aba) => setState(() => _aba = aba),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Agências'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
