import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../tema.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key, required this.sessao, required this.config, required this.prefs});

  final Sessao sessao;
  final Configuracao config;
  final SharedPreferences prefs;

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  bool _entrando = false;
  bool _mostrarSenha = false;
  String? _erro;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _entrando = true;
      _erro = null;
    });
    try {
      await widget.sessao.entrar(_usuario.text.trim(), _senha.text);
    } on ApiErro catch (erro) {
      setState(() => _erro = '${erro.mensagem} (HTTP ${erro.status})');
    } on SemConexao {
      setState(() => _erro = 'Nenhuma agência respondeu em ${widget.config.host}. '
          'Confira se as agências estão no ar e o endereço do servidor.');
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<void> _configurarServidor() async {
    final campo = TextEditingController(text: widget.config.host);
    final novo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Endereço das agências'),
        content: TextField(
          controller: campo,
          decoration: InputDecoration(
            labelText: 'Host',
            helperText: 'Portas ${Configuracao.portaBase}-${Configuracao.portaBase + 2}. No emulador, use 10.0.2.2.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, campo.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (novo == null || novo.isEmpty) return;
    widget.config.host = novo;
    await widget.prefs.setString('host', novo);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final motivo = widget.sessao.motivoSaida;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: Cores.primaria, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ICEIBank',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const Text('Banco distribuído em 3 agências',
                textAlign: TextAlign.center, style: TextStyle(color: Cores.textoSecundario)),
            const SizedBox(height: 32),
            if (motivo != null) ...[
              Bloco(
                cor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_outlined, color: Cores.debito),
                    const SizedBox(width: 10),
                    Expanded(child: Text(motivo, style: const TextStyle(color: Cores.debito))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _usuario,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senha,
              obscureText: !_mostrarSenha,
              onSubmitted: (_) => _entrar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                  icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _entrando ? null : _entrar,
              child: _entrando
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Entrar'),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 14),
              Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(color: Cores.debito)),
            ],
            const SizedBox(height: 28),
            Center(
              child: TextButton.icon(
                onPressed: _configurarServidor,
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: Text('Agências em ${widget.config.host}'),
                style: TextButton.styleFrom(foregroundColor: Cores.textoSecundario),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
