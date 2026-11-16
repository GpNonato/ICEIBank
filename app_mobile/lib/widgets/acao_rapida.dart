import 'package:material_ui/material_ui.dart';

import '../tema.dart';

/// Cartão da grade de ações rápidas (ícone, título e descrição).
class AcaoRapida extends StatelessWidget {
  const AcaoRapida({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.cor,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final Color cor;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final ativo = aoTocar != null;
    return Opacity(
      opacity: ativo ? 1 : 0.5,
      child: Bloco(
        aoTocar: aoTocar,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconeRedondo(icone, cor: cor, tamanho: 36),
            const Spacer(),
            Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Cores.texto)),
            const SizedBox(height: 2),
            Text(
              descricao,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
