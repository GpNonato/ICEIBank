import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Aba "Perfil": sessão JWT, endereço das agências e saída.
class PerfilTela extends StatelessWidget {
  const PerfilTela({super.key, required this.sessao, required this.config, required this.aoSair});

  final Sessao sessao;
  final Configuracao config;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    final usuario = sessao.usuario ?? '';
    final expira = sessao.expiraEm;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Bloco(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Cores.primaria,
                child: Text(
                  usuario.isEmpty ? '?' : usuario[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      expira == null ? 'Sessão ativa' : 'Token JWT válido até ${hora(expira)}',
                      style: const TextStyle(color: Cores.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Bloco(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const IconeRedondo(Icons.dns_outlined, cor: Cores.destaque),
                title: const Text('Agências'),
                subtitle: Text(
                  'http://${config.host}:${Configuracao.portaBase}-${Configuracao.portaBase + 2}',
                ),
              ),
              const ListTile(
                leading: IconeRedondo(Icons.hub_outlined, cor: Cores.lider),
                title: Text('Particionamento'),
                subtitle: Text('Conta atendida pela agência número da conta % 3'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: aoSair,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Cores.debito,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: Cores.borda),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
