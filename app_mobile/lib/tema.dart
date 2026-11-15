import 'package:material_ui/material_ui.dart';

/// Paleta e componentes visuais do app (tema claro, cartões brancos arredondados).
class Cores {
  static const fundo = Color(0xFFF4F5F7);
  static const cartao = Colors.white;
  static const texto = Color(0xFF111827);
  static const textoSecundario = Color(0xFF6B7280);
  static const borda = Color(0xFFE5E7EB);
  static const primaria = Color(0xFF111827);
  static const destaque = Color(0xFF2563EB);
  static const credito = Color(0xFF16A34A);
  static const debito = Color(0xFFDC2626);
  static const alerta = Color(0xFFD97706);
  static const lider = Color(0xFFF59E0B);
}

ThemeData criarTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.destaque,
    brightness: Brightness.light,
  ).copyWith(
    primary: Cores.primaria,
    onPrimary: Colors.white,
    surface: Cores.cartao,
    onSurface: Cores.texto,
    error: Cores.debito,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cores.primaria,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Cores.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Cores.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Cores.primaria, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Cores.fundo,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: estados.contains(WidgetState.selected) ? Cores.texto : Cores.textoSecundario,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Cartão branco com cantos arredondados e sombra suave.
class Bloco extends StatelessWidget {
  const Bloco({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.aoTocar, this.cor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? aoTocar;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cor ?? Cores.cartao,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: aoTocar,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Ícone dentro de um círculo colorido claro.
class IconeRedondo extends StatelessWidget {
  const IconeRedondo(this.icone, {super.key, this.cor = Cores.texto, this.tamanho = 40});

  final IconData icone;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icone, color: cor, size: tamanho * 0.5),
    );
  }
}

class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Cores.texto)),
          const Spacer(),
          ?acao,
        ],
      ),
    );
  }
}
