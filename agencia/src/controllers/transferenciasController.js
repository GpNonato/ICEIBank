import axios from 'axios';
import * as config from '../config.js';

async function transferir(req, res) {
  const { contas, relogio, registro, idAgencia } = req.app.locals;
  const { idOrigem, idDestino, valor } = req.body;

  const contaOrigem = contas.get(idOrigem);
  if (!contaOrigem) return res.status(404).json({ erro: 'Conta de origem não encontrada nesta agência.' });
  if (contaOrigem.saldo < valor) return res.status(400).json({ erro: 'Saldo insuficiente.' });

  const agenciaDestino = config.agenciaResponsavel(idDestino);

  const tsDebito = relogio.eventoLocal();
  contaOrigem.saldo -= valor;
  registro.registrar('TRANSFERENCIA_DEBITO', tsDebito, { idOrigem, idDestino, valor });

  if (agenciaDestino === idAgencia) {
    const contaDestino = contas.get(idDestino);
    if (!contaDestino) {
      contaOrigem.saldo += valor;
      return res.status(404).json({ erro: 'Conta de destino não encontrada.' });
    }
    const tsCredito = relogio.eventoLocal();
    contaDestino.saldo += valor;
    registro.registrar('TRANSFERENCIA_CREDITO', tsCredito, { idOrigem, idDestino, valor });
    return res.json({ mensagem: 'Transferência concluída (mesma agência).' });
  }

  const tsEnvio = relogio.aoEnviar();
  const urlDestino = config.AGENCIAS.find((a) => a.id === agenciaDestino).url;

  try {
    await axios.post(`${urlDestino}/contas/${idDestino}/creditar-remoto`, {
      valor,
      timestampLamport: tsEnvio,
      origemAgencia: idAgencia,
    });
    res.json({ mensagem: 'Transferência concluída (entre agências).' });
  } catch (erro) {
    registro.registrar('TRANSFERENCIA_FALHOU', relogio.eventoLocal(), {
      idOrigem, idDestino, valor, erro: erro.message,
    });
    res.status(502).json({
      erro: 'Falha ao contatar agência de destino. Débito já aplicado - inconsistência conhecida (ver Sprint 4).',
    });
  }
}

async function creditarRemoto(req, res) {
  const { contas, relogio, registro } = req.app.locals;
  const idConta = parseInt(req.params.id, 10);
  const { valor, timestampLamport, origemAgencia } = req.body;


  const ts = relogio.aoReceber(timestampLamport);

  const conta = contas.get(idConta);
  if (!conta) return res.status(404).json({ erro: 'Conta não encontrada nesta agência.' });

  conta.saldo += valor;
  registro.registrar('TRANSFERENCIA_CREDITO_REMOTO', ts, { idConta, valor, origemAgencia });

  res.json({ mensagem: 'Crédito remoto aplicado.', saldoAtual: conta.saldo });
}

export { transferir, creditarRemoto };