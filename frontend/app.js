(function () {
  'use strict';

  var AG_URLS = ['http://localhost:4042', 'http://localhost:4043', 'http://localhost:4044'];
  var NUMERO_AGENCIAS = 3;
  var DIM = '#8a8a8a', FG = '#f2f2f2';
  var CHAVE_TOKEN = 'iceibank_token';

  var PUBLIC_CMDS = ['entrar', 'ajuda', 'limpar'];

  var HELP = [
    ['entrar <usuario> <senha>', 'autentica e guarda o token'],
    ['agencia <0|1|2>', 'troca a agência conectada'],
    ['saldo <conta>', 'mostra titular, agência e saldo atual'],
    ['depositar <conta> <valor>', 'credita um valor na conta'],
    ['sacar <conta> <valor>', 'debita um valor da conta'],
    ['transferir <origem> <destino> <valor> [id-operacao]', 'faz transferência local ou entre agências'],
    ['criar <conta> <nome> <saldo>', 'abre uma conta na agência conectada'],
    ['historico <conta>', 'lista os eventos registrados para uma conta'],
    ['limites', 'mostra os limites de saque e transferência'],
    ['extrato <nome>', 'soma as contas de um titular nas três agências'],
    ['status [agencia]', 'mostra o estado e o relógio de uma agência'],
    ['swagger [agencia]', 'abre a documentação da agência'],
    ['sair', 'encerra a sessão e remove o token'],
    ['limpar', 'limpa o terminal', true],
    ['ajuda', 'lista os comandos disponíveis', true]
  ];

  var portaAtual = Number(window.location.port);
  var agenciaInicial = portaAtual >= 4042 && portaAtual <= 4044 ? portaAtual - 4042 : 0;

  var estado = {
    hist: [], histPos: -1, agencia: agenciaInicial, token: null, usuario: '', ocupado: false
  };

  var el = {
    terminal: document.getElementById('terminal'),
    log: document.getElementById('log'),
    logConteudo: document.getElementById('log-conteudo'),
    rotuloAgencia: document.getElementById('rotulo-agencia'),
    prompt: document.getElementById('prompt'),
    fantasmaDigitado: document.getElementById('fantasma-digitado'),
    fantasmaRestante: document.getElementById('fantasma-restante'),
    input: document.getElementById('cmd')
  };

  function ErroApi(status, mensagem) { this.status = status; this.message = mensagem; }
  ErroApi.prototype = Object.create(Error.prototype);

  function ErroRede(mensagem) { this.message = mensagem; }
  ErroRede.prototype = Object.create(Error.prototype);

  function out(texto, cor, recuo) {
    var linha = document.createElement('div');
    linha.className = 'linha';
    linha.style.color = cor || FG;
    linha.style.paddingLeft = (recuo || 0) + 'px';

    var spanTexto = document.createElement('span');
    spanTexto.className = 'texto';
    spanTexto.textContent = texto === undefined ? '' : texto;

    var spanSufixo = document.createElement('span');
    spanSufixo.className = 'sufixo';

    linha.appendChild(spanTexto);
    linha.appendChild(spanSufixo);
    el.logConteudo.appendChild(linha);
    el.log.scrollTop = el.log.scrollHeight;
  }

  function marcarUltima(sufixo) {
    var ultima = el.logConteudo.lastElementChild;
    if (ultima) ultima.querySelector('.sufixo').textContent = sufixo;
  }

  function limpar() { el.logConteudo.textContent = ''; }

  function money(n) {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(Number(n));
  }

  function agenciaResponsavel(id) { return Number(id) % NUMERO_AGENCIAS; }

  function gerarIdOperacao() {
    if (window.crypto && typeof window.crypto.randomUUID === 'function') {
      return window.crypto.randomUUID();
    }
    return 'operacao-' + Date.now() + '-' + Math.random().toString(16).slice(2);
  }

  function focar() {
    var selecao = window.getSelection();
    if (selecao && selecao.toString()) return;
    el.input.focus();
  }

  function atualizarCabecalho() {
    el.rotuloAgencia.textContent = estado.token ? 'agência ' + estado.agencia : '';
    el.prompt.textContent = estado.usuario;
    el.prompt.hidden = !estado.token;
  }

  function iniciarSessao(token, usuario) {
    estado.token = token;
    estado.usuario = usuario;
    try { localStorage.setItem(CHAVE_TOKEN, token); } catch (e) {}
    atualizarCabecalho();
  }

  function encerrarSessao() {
    estado.token = null;
    estado.usuario = '';
    try { localStorage.removeItem(CHAVE_TOKEN); } catch (e) {}
    atualizarCabecalho();
  }

  function lerToken(token) {
    try {
      var parte = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      return JSON.parse(atob(parte + '==='.slice((parte.length + 3) % 4)));
    } catch (e) { return null; }
  }

  function restaurarSessao() {
    var token;
    try { token = localStorage.getItem(CHAVE_TOKEN); } catch (e) { return; }
    if (!token) return;
    var dados = lerToken(token);
    if (!dados || !dados.exp || dados.exp * 1000 <= Date.now()) {
      try { localStorage.removeItem(CHAVE_TOKEN); } catch (e) {}
      return;
    }
    estado.token = token;
    estado.usuario = dados.sub || '';
    atualizarCabecalho();
  }

  function autenticado() {
    if (!estado.token) { out('! token ausente — execute entrar', FG); return false; }
    return true;
  }

  async function api(metodo, caminho, corpo, agencia) {
    var indice = agencia === undefined ? estado.agencia : agencia;
    var opcoes = { method: metodo, headers: {} };
    if (corpo !== undefined) {
      opcoes.headers['Content-Type'] = 'application/json';
      opcoes.body = JSON.stringify(corpo);
    }
    if (estado.token) opcoes.headers['Authorization'] = 'Bearer ' + estado.token;

    var resposta;
    try {
      resposta = await fetch(AG_URLS[indice] + caminho, opcoes);
    } catch (e) {
      throw new ErroRede('agência ' + indice + ' indisponível · ' + AG_URLS[indice]);
    }

    var dados = null;
    try { dados = await resposta.json(); } catch (e) {}

    if (!resposta.ok) {
      var mensagem = (dados && (dados.erro || dados.detail)) || ('HTTP ' + resposta.status);
      if (typeof mensagem !== 'string') mensagem = 'HTTP ' + resposta.status;
      throw new ErroApi(resposta.status, mensagem);
    }
    return dados;
  }

  function relatarErro(erro) {
    if (erro instanceof ErroApi && erro.status === 401) {
      encerrarSessao();
      out('! ' + erro.message + ' — execute entrar');
      return;
    }
    out('! ' + (erro && erro.message ? erro.message : 'erro inesperado na interface'));
  }

  async function req(endpoint, fn) {
    marcarUltima(endpoint);
    estado.ocupado = true;
    try { await fn(); }
    catch (erro) { relatarErro(erro); }
    finally { estado.ocupado = false; }
  }

  function naoEncontrada(id) {
    out('! conta ' + id + ' não existe na agência ' + estado.agencia);
  }

  async function saldoDisponivel(id) {
    try { return (await api('GET', '/contas/' + id)).saldo; }
    catch (e) { return null; }
  }

  async function avisarSaldoInsuficiente(id) {
    var saldo = await saldoDisponivel(id);
    if (saldo === null) out('! saldo insuficiente');
    else out('! saldo insuficiente · disponível ' + money(saldo));
  }

  function help() {
    var on = !!estado.token;
    return HELP.filter(function (h) {
      var n = h[0].split(/\s+/)[0];
      if (n === 'entrar') return !on;
      return on || PUBLIC_CMDS.indexOf(n) >= 0;
    });
  }

  function ghost() {
    var raw = el.input.value;
    if (!raw) return ['', ''];
    var endsSpace = /\s$/.test(raw);
    var toks = raw.trim().split(/\s+/);
    var word = toks[0].toLowerCase();
    var argCount = toks.length - 1;
    var entries = help().map(function (h) { return h[0].split(/\s+/); });

    var exact = entries.find(function (p) { return p[0] === word; });
    if (exact) {
      var rest = exact.slice(1 + argCount);
      if (!rest.length) return ['', ''];
      return [raw, (endsSpace ? '' : ' ') + rest.join(' ')];
    }
    if (argCount > 0) return ['', ''];

    var hits = entries.filter(function (p) { return p[0].indexOf(word) === 0; });
    if (hits.length !== 1) return ['', ''];
    var p = hits[0];
    return [raw, p[0].slice(word.length) + (p.length > 1 ? ' ' + p.slice(1).join(' ') : '')];
  }

  function atualizarFantasma() {
    var g = ghost();
    el.fantasmaDigitado.textContent = g[0];
    el.fantasmaRestante.textContent = g[1];
  }

  function contaValida(id) { return typeof id === 'string' && /^\d+$/.test(id); }

  async function exec(raw) {
    var linha = raw.trim();
    if (linha && !/^entrar\s/i.test(linha)) estado.hist.push(linha);
    estado.histPos = -1;
    el.input.value = '';
    atualizarFantasma();

    var linhaSegura = raw.replace(/^(\s*entrar\s+\S+\s+).+$/i, '$1********');
    out((estado.token ? estado.usuario + ' ' : '') + '> ' + linhaSegura);
    if (!linha) return;

    var p = linha.split(/\s+/);
    var c = p[0].toLowerCase();

    if (c === 'limpar') { limpar(); return; }

    if (c === 'ajuda') {
      help().filter(function (h) { return !h[2]; }).forEach(function (h) {
        out('> ' + h[0]);
        out(h[1], DIM, 26);
      });
      return;
    }

    if (c === 'entrar') {
      if (estado.token) return out('! sessão já está ativa — execute sair primeiro');
      if (p.length < 3) return out('uso: entrar <usuario> <senha>', DIM);
      return req('POST /auth/login', async function () {
        var dados;
        try {
          dados = await api('POST', '/auth/login', { usuario: p[1], senha: p[2] });
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 401) return out('! usuário ou senha inválidos');
          throw erro;
        }
        iniciarSessao(dados.access_token, p[1]);
        out('sessão iniciada · token guardado neste navegador', DIM);
      });
    }

    if (c === 'sair') {
      if (!autenticado()) return;
      encerrarSessao();
      return out('sessão encerrada · token removido', DIM);
    }

    if (c === 'agencia') {
      if (!autenticado()) return;
      var n = parseInt(p[1], 10);
      if (!(n >= 0 && n <= NUMERO_AGENCIAS - 1)) return out('uso: agencia <0|1|2>', DIM);
      estado.agencia = n;
      atualizarCabecalho();
      return out('conectado à agência ' + n + ' · ' + AG_URLS[n], DIM);
    }

    if (c === 'status') {
      if (!autenticado()) return;
      var agenciaStatus = p[1] === undefined ? estado.agencia : parseInt(p[1], 10);
      if (!(agenciaStatus >= 0 && agenciaStatus <= NUMERO_AGENCIAS - 1)) {
        return out('uso: status [agencia]', DIM);
      }
      return req('GET /status', async function () {
        var dadosStatus = await api('GET', '/status', undefined, agenciaStatus);
        out('agência ' + dadosStatus.agencia + ' · ' + dadosStatus.status, DIM);
        out('relógio de Lamport: ' + dadosStatus.relogioLamport + ' · contas: ' + dadosStatus.quantidadeContas);
      });
    }

    if (c === 'swagger') {
      if (!autenticado()) return;
      var agenciaSwagger = p[1] === undefined ? estado.agencia : parseInt(p[1], 10);
      if (!(agenciaSwagger >= 0 && agenciaSwagger <= NUMERO_AGENCIAS - 1)) {
        return out('uso: swagger [agencia]', DIM);
      }
      var urlSwagger = AG_URLS[agenciaSwagger] + '/docs';
      var janelaSwagger = window.open('', '_blank');
      if (!janelaSwagger) return out('! o navegador bloqueou a abertura do Swagger');
      return req('GET /docs', async function () {
        var resposta;
        try {
          resposta = await fetch(urlSwagger, {
            headers: { Authorization: 'Bearer ' + estado.token }
          });
        } catch (erro) {
          janelaSwagger.close();
          throw new ErroRede('agência ' + agenciaSwagger + ' indisponível · ' + AG_URLS[agenciaSwagger]);
        }
        if (!resposta.ok) {
          janelaSwagger.close();
          var dadosErro = null;
          try { dadosErro = await resposta.json(); } catch (erro) {}
          throw new ErroApi(
            resposta.status,
            (dadosErro && (dadosErro.erro || dadosErro.detail)) || ('HTTP ' + resposta.status)
          );
        }
        janelaSwagger.document.open();
        janelaSwagger.document.write(await resposta.text());
        janelaSwagger.document.close();
        out('Swagger da agência ' + agenciaSwagger + ' aberto', DIM);
      });
    }

    if (c === 'saldo') {
      if (!autenticado()) return;
      var idSaldo = p[1];
      if (!contaValida(idSaldo)) return out('uso: saldo <conta>', DIM);
      return req('GET /contas/' + idSaldo, async function () {
        var conta;
        try {
          conta = await api('GET', '/contas/' + idSaldo);
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 404) return naoEncontrada(idSaldo);
          throw erro;
        }
        out(conta.nomeAluno + ' · conta ' + conta.id + ' · agência ' + estado.agencia, DIM);
        out(money(conta.saldo));
      });
    }

    if (c === 'depositar' || c === 'sacar') {
      if (!autenticado()) return;
      var idMov = p[1], valor = parseFloat(p[2]);
      if (!contaValida(idMov) || !(valor > 0)) return out('uso: ' + c + ' <conta> <valor>', DIM);
      var sacando = c === 'sacar';
      var caminho = '/contas/' + idMov + (sacando ? '/sacar' : '/depositar');
      return req('POST ' + caminho, async function () {
        var conta;
        try {
          conta = await api('POST', caminho, { valor: valor });
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 404) return naoEncontrada(idMov);
          if (erro instanceof ErroApi && erro.status === 400 && sacando && /saldo insuficiente/i.test(erro.message)) {
            return avisarSaldoInsuficiente(idMov);
          }
          throw erro;
        }
        out((sacando ? 'saque' : 'depósito') + ' de ' + money(valor) + ' concluído', DIM);
        out(money(conta.saldo));
      });
    }

    if (c === 'transferir') {
      if (!autenticado()) return;
      var origem = p[1], destino = p[2], v = parseFloat(p[3]);
      if (!contaValida(origem) || !contaValida(destino) || !(v > 0)) {
        return out('uso: transferir <origem> <destino> <valor> [id-operacao]', DIM);
      }
      if (origem === destino) return out('! as contas de origem e destino devem ser diferentes');
      var agO = agenciaResponsavel(origem), agD = agenciaResponsavel(destino);
      if (agO !== estado.agencia) {
        return out('! conta ' + origem + ' pertence à agência ' + agO + ' — execute: agencia ' + agO);
      }
      var idOperacao = p[4] || gerarIdOperacao();
      return req('POST /transferencias', async function () {
        var resultadoTransferencia;
        try {
          resultadoTransferencia = await api('POST', '/transferencias', {
            idOrigem: Number(origem), idDestino: Number(destino), valor: v, idOperacao: idOperacao
          });
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 400 && /saldo insuficiente/i.test(erro.message)) {
            return avisarSaldoInsuficiente(origem);
          }
          throw erro;
        }
        var tipoTransferencia = agO === agD ? 'local' : 'entre agências · agência ' + agD;
        if (resultadoTransferencia.repetida) {
          out('transferência repetida reconhecida · nenhum valor aplicado novamente', DIM);
        } else {
          out('transferência de ' + money(v) + ' concluída · ' + tipoTransferencia +
              ' · conta ' + origem + ' → conta ' + destino, DIM);
        }
        out('identificador: ' + resultadoTransferencia.idOperacao, DIM);
        var saldo = await saldoDisponivel(origem);
        if (saldo !== null) out(money(saldo));
      });
    }

    if (c === 'criar') {
      if (!autenticado()) return;
      var idNovo = p[1], nome = p[2], s0 = parseFloat(p[3]);
      if (!contaValida(idNovo) || !nome || isNaN(s0)) {
        return out('uso: criar <conta> <nome> <saldo>', DIM);
      }
      return req('POST /contas', async function () {
        var conta;
        try {
          conta = await api('POST', '/contas', {
            id: Number(idNovo), nomeAluno: nome, saldoInicial: s0
          });
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 409) {
            return out('! conta ' + idNovo + ' já existe na agência ' + estado.agencia);
          }
          if (erro instanceof ErroApi && erro.status === 400) {
            var dona = agenciaResponsavel(idNovo);
            return out('! conta ' + idNovo + ' pertence à agência ' + dona + ' — execute: agencia ' + dona);
          }
          throw erro;
        }
        out('conta ' + conta.id + ' criada para ' + conta.nomeAluno + ' na agência ' + estado.agencia, DIM);
        out(money(conta.saldo));
      });
    }

    if (c === 'historico') {
      if (!autenticado()) return;
      var idHistorico = p[1];
      if (!contaValida(idHistorico)) return out('uso: historico <conta>', DIM);
      return req('GET /contas/' + idHistorico + '/historico', async function () {
        var dadosHistorico;
        try {
          dadosHistorico = await api('GET', '/contas/' + idHistorico + '/historico');
        } catch (erro) {
          if (erro instanceof ErroApi && erro.status === 404) return naoEncontrada(idHistorico);
          throw erro;
        }
        if (!dadosHistorico.eventos.length) return out('nenhum evento encontrado para a conta ' + idHistorico, DIM);
        dadosHistorico.eventos.forEach(function (evento) {
          out('[Lamport ' + evento.timestampLamport + '] ' + evento.tipo, DIM);
          out(JSON.stringify(evento.detalhes), FG, 26);
        });
      });
    }

    if (c === 'limites') {
      if (!autenticado()) return;
      return req('GET /limites', async function () {
        var dadosLimites = await api('GET', '/limites');
        out('limite de saque: ' + money(dadosLimites.limiteSaque), DIM);
        out('limite de transferência: ' + money(dadosLimites.limiteTransferencia), DIM);
      });
    }

    if (c === 'extrato') {
      if (!autenticado()) return;
      var nomeExtrato = p.slice(1).join(' ');
      if (!nomeExtrato) return out('uso: extrato <nome>', DIM);
      return req('GET /extratos/consolidado/' + encodeURIComponent(nomeExtrato), async function () {
        var dadosExtrato = await api('GET', '/extratos/consolidado/' + encodeURIComponent(nomeExtrato));
        if (!dadosExtrato.contas.length) return out('nenhuma conta encontrada para ' + nomeExtrato, DIM);
        dadosExtrato.contas.forEach(function (contaExtrato) {
          out('conta ' + contaExtrato.id + ' · agência ' + agenciaResponsavel(contaExtrato.id) + ' · ' + money(contaExtrato.saldo), DIM);
        });
        out('saldo consolidado: ' + money(dadosExtrato.saldoTotal));
      });
    }

    out('! comando desconhecido: ' + c + ' — digite ajuda', FG);
  }

  el.input.addEventListener('input', atualizarFantasma);

  el.input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (estado.ocupado) return;
      exec(el.input.value);
      return;
    }

    if (e.key === 'Tab') {
      e.preventDefault();
      var raw = el.input.value;
      if (!raw.trim() || /\s/.test(raw.trim())) return;
      var word = raw.trim().toLowerCase();
      var hits = help()
        .map(function (h) { return h[0].split(/\s+/)[0]; })
        .filter(function (n) { return n.indexOf(word) === 0; });
      if (hits.length === 1) { el.input.value = hits[0] + ' '; atualizarFantasma(); }
      return;
    }

    if (e.key === 'ArrowUp') {
      e.preventDefault();
      var hUp = estado.hist;
      if (!hUp.length) return;
      var pUp = estado.histPos < 0 ? hUp.length - 1 : Math.max(0, estado.histPos - 1);
      estado.histPos = pUp;
      el.input.value = hUp[pUp];
      atualizarFantasma();
      return;
    }

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      var hDown = estado.hist;
      if (estado.histPos < 0) return;
      var pDown = estado.histPos + 1;
      if (pDown >= hDown.length) { estado.histPos = -1; el.input.value = ''; }
      else { estado.histPos = pDown; el.input.value = hDown[pDown]; }
      atualizarFantasma();
    }
  });

  el.terminal.addEventListener('click', focar);

  restaurarSessao();
  atualizarCabecalho();
  atualizarFantasma();
  focar();
})();
