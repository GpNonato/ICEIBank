import 'package:material_ui/material_ui.dart';

import '../servicos/api.dart';
import '../servicos/conectividade.dart';
import '../servicos/contas.dart';
import '../servicos/lideranca.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import '../widgets/acao_rapida.dart';
import '../widgets/cartao_saldo.dart';
import '../widgets/faixa_lideranca.dart';
import '../widgets/folhas.dart';
import '../widgets/item_operacao.dart';

/// Aba "Início": saudação, líder atual, saldo, fila offline, ações rápidas e atividade.
class InicioTela extends StatefulWidget {
  const InicioTela({
    super.key,
    required this.sessao,
    required this.lideranca,
    required this.contas,
    required this.conectividade,
    required this.aoAbrirAgencias,
  });

  final Sessao sessao;
  final LiderancaServico lideranca;
  final ContasServico contas;
  final ConectividadeServico conectividade;
  final VoidCallback aoAbrirAgencias;

  @override
  State<InicioTela> createState() => _InicioTelaState();
}

class _InicioTelaState extends State<InicioTela> {
  bool _ocupado = false;
  String? _erroConta;

  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia,';
    if (hora < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  String get _nome {
    final usuario = widget.sessao.usuario ?? '';
    return usuario.isEmpty ? 'cliente' : usuario[0].toUpperCase() + usuario.substring(1);
  }

  void _mostrar(String mensagem, {Color? cor}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor ?? Cores.primaria));
  }

  String _descreverErro(Object erro) => switch (erro) {
        ApiErro(:final mensagem, :final status) => '$mensagem (HTTP $status)',
        SemConexao() => '${erro.toString()} Ainda não há dados salvos desta conta no aparelho.',
        OperacaoInvalida(:final mensagem) => mensagem,
        _ => 'Erro inesperado: $erro',
      };

  Future<void> _acessarConta([int? id]) async {
    final numero = id ?? await pedirConta(context);
    if (numero == null) return;
    setState(() {
      _ocupado = true;
      _erroConta = null;
    });
    try {
      await widget.contas.consultar(numero);
    } catch (erro) {
      widget.contas.limpar();
      setState(() => _erroConta = 'Conta $numero: ${_descreverErro(erro)}');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _executar(Future<String> Function() operacao) async {
    setState(() => _ocupado = true);
    try {
      final mensagem = await operacao();
      final offline = widget.contas.operacoes.isNotEmpty && widget.contas.operacoes.first.status == 'pendente';
      _mostrar(mensagem, cor: offline ? Cores.alerta : null);
    } catch (erro) {
      _mostrar(_descreverErro(erro), cor: Cores.debito);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _depositar() async {
    final valor = await pedirValor(context,
        titulo: 'Depositar', subtitulo: 'Crédito na conta ${widget.contas.conta!.id}.', acao: 'Depositar');
    if (valor != null) await _executar(() => widget.contas.depositar(valor));
  }

  Future<void> _sacar() async {
    final valor = await pedirValor(context,
        titulo: 'Sacar', subtitulo: 'Débito na conta ${widget.contas.conta!.id}.', acao: 'Sacar');
    if (valor != null) await _executar(() => widget.contas.sacar(valor));
  }

  Future<void> _transferir() async {
    final dados = await pedirTransferencia(context, widget.contas.conta!.id);
    if (dados != null) await _executar(() => widget.contas.transferir(dados.$1, dados.$2));
  }

  Widget _banner() {
    final contas = widget.contas;
    final online = widget.conectividade.online;
    final pendentes = contas.pendentes.length;
    if (online && !contas.sincronizando) return const SizedBox.shrink();
    final (cor, fundo, icone, texto) = !online
        ? (
            Cores.alerta,
            const Color(0xFFFFF7ED),
            Icons.airplanemode_active_rounded,
            'Sem conexão. Mostrando os dados salvos no aparelho; operações ficam na fila'
                '${pendentes > 0 ? ' ($pendentes pendente${pendentes > 1 ? 's' : ''})' : ''}.',
          )
        : (
            Cores.destaque,
            const Color(0xFFEFF6FF),
            Icons.sync_rounded,
            'Conexão restabelecida. Sincronizando $pendentes ${pendentes == 1 ? 'operação' : 'operações'}...',
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Bloco(
        cor: fundo,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icone, color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  /// Fila offline: pendentes, conflitos e as sincronizadas há pouco.
  Widget _filaOffline() {
    final agora = DateTime.now();
    final itens = widget.contas.operacoes
        .where((o) =>
            o.offline &&
            (o.emAberto || (o.resolvidaEm != null && agora.difference(o.resolvidaEm!).inMinutes < 3)))
        .toList();
    if (itens.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSecao('Sincronização offline'),
        Bloco(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Cores.borda),
                ItemOperacao(
                  operacao: itens[i],
                  aoReenviar: () => widget.contas.reenviar(itens[i]),
                  aoDescartar: () => widget.contas.descartar(itens[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.contas, widget.conectividade]),
      builder: (context, _) {
        final contas = widget.contas;
        final conta = contas.conta;
        final recentes = contas.operacoes.where((o) => !o.emAberto).take(8).toList();
        final podeOperar = conta != null && !_ocupado;
        return RefreshIndicator(
          onRefresh: () async {
            await widget.lideranca.consultar();
            if (conta != null) await _acessarConta(conta.id);
            await contas.sincronizar();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Cores.primaria,
                    child: Text(_nome[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_saudacao, style: const TextStyle(fontSize: 13, color: Cores.textoSecundario)),
                        Text(_nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (_ocupado || contas.sincronizando)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 16),
              _banner(),
              FaixaLideranca(lideranca: widget.lideranca, aoTocar: widget.aoAbrirAgencias),
              const SizedBox(height: 12),
              if (conta != null)
                CartaoSaldo(
                  conta: conta,
                  saldoProvisorio: contas.saldoProvisorio(conta),
                  pendentes: contas.pendentesDa(conta.id).length,
                  aoTrocarConta: () => _acessarConta(),
                )
              else
                Bloco(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nenhuma conta aberta',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Informe o número da conta para ver o saldo e operar.',
                          style: TextStyle(color: Cores.textoSecundario)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _ocupado ? null : () => _acessarConta(),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Acessar conta'),
                      ),
                    ],
                  ),
                ),
              if (_erroConta != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Bloco(
                    cor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Cores.debito),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_erroConta!, style: const TextStyle(color: Cores.debito))),
                      ],
                    ),
                  ),
                ),
              _filaOffline(),
              const TituloSecao('Ações rápidas'),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 116,
                ),
                children: [
                  AcaoRapida(
                    icone: Icons.add_rounded,
                    titulo: 'Depositar',
                    descricao: 'Adicionar saldo',
                    cor: Cores.credito,
                    aoTocar: podeOperar ? _depositar : null,
                  ),
                  AcaoRapida(
                    icone: Icons.remove_rounded,
                    titulo: 'Sacar',
                    descricao: 'Retirar da conta',
                    cor: Cores.debito,
                    aoTocar: podeOperar ? _sacar : null,
                  ),
                  AcaoRapida(
                    icone: Icons.swap_horiz_rounded,
                    titulo: 'Transferir',
                    descricao: 'Local ou entre agências',
                    cor: Cores.destaque,
                    aoTocar: podeOperar ? _transferir : null,
                  ),
                  AcaoRapida(
                    icone: Icons.refresh_rounded,
                    titulo: 'Atualizar',
                    descricao: 'Consultar saldo agora',
                    cor: Cores.texto,
                    aoTocar: podeOperar ? () => _acessarConta(conta.id) : null,
                  ),
                ],
              ),
              const TituloSecao('Atividade recente'),
              Bloco(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: recentes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text('As operações feitas no app aparecem aqui.',
                              style: TextStyle(color: Cores.textoSecundario)),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < recentes.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: Cores.borda),
                            ItemOperacao(operacao: recentes[i]),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
