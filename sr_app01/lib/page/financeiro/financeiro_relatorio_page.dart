import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class FinanceiroRelatorioPage extends StatefulWidget {
  const FinanceiroRelatorioPage({super.key});

  @override
  State<FinanceiroRelatorioPage> createState() => _FinanceiroRelatorioPageState();
}

class _FinanceiroRelatorioPageState extends State<FinanceiroRelatorioPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _nomeProfissional = 'Carregando...';

  // Filtros selecionados
  String _filtroPeriodo = 'Período';
  String _filtroDias = '15 dias';
  String _filtroFrequencia = 'Diário';

  DateTimeRange? _intervaloDatasPersonalizado;

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  Future<void> _buscarNomeProfissional() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final dadosPerfil = await _supabase
            .from('perfis')
            .select('nome')
            .eq('id', user.id)
            .maybeSingle();

        if (dadosPerfil != null && dadosPerfil['nome'] != null) {
          setState(() => _nomeProfissional = dadosPerfil['nome']);
        } else {
          setState(() => _nomeProfissional = 'Profissional');
        }
      }
    } catch (_) {
      setState(() => _nomeProfissional = 'Profissional');
    }
  }

  Future<void> _selecionarIntervaloDatas() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? novoIntervalo = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _intervaloDatasPersonalizado ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE4C47A),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (novoIntervalo != null) {
      setState(() {
        _intervaloDatasPersonalizado = novoIntervalo;
        final String inicio = DateFormat('dd/MM', 'pt_BR').format(novoIntervalo.start);
        final String fim = DateFormat('dd/MM', 'pt_BR').format(novoIntervalo.end);
        _filtroPeriodo = '$inicio a $fim';
        _filtroDias = 'Todos';
      });
    }
  }

  // Busca entradas e saídas financeiras
  Future<List<Map<String, dynamic>>> _buscarLancamentosRelatorio() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    var query = _supabase
        .from('lancamentos_financeiros')
        .select()
        .eq('id_usuario', user.id)
        .neq('status', 'CANCELADO');

    final agora = DateTime.now();

    if (_intervaloDatasPersonalizado != null && _filtroPeriodo != 'Período') {
      final inicioIso = DateTime(
        _intervaloDatasPersonalizado!.start.year,
        _intervaloDatasPersonalizado!.start.month,
        _intervaloDatasPersonalizado!.start.day,
        0, 0, 0,
      ).toIso8601String();

      final fimIso = DateTime(
        _intervaloDatasPersonalizado!.end.year,
        _intervaloDatasPersonalizado!.end.month,
        _intervaloDatasPersonalizado!.end.day,
        23, 59, 59,
      ).toIso8601String();

      query = query.gte('created_at', inicioIso).lte('created_at', fimIso);
    } else if (_filtroPeriodo == 'Mês Atual') {
      final inicioMes = DateTime(agora.year, agora.month, 1);
      query = query.gte('created_at', inicioMes.toIso8601String());
    } else if (_filtroPeriodo == 'Ano Atual') {
      final inicioAno = DateTime(agora.year, 1, 1);
      query = query.gte('created_at', inicioAno.toIso8601String());
    } else {
      int? diasAtras;
      if (_filtroDias == '7 dias') diasAtras = 7;
      if (_filtroDias == '15 dias') diasAtras = 15;
      if (_filtroDias == '30 dias') diasAtras = 30;

      if (diasAtras != null) {
        final dataInicio = agora.subtract(Duration(days: diasAtras));
        query = query.gte('created_at', dataInicio.toIso8601String());
      }
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Função para gerar PDF do Comprovante / Nota Fiscal
  Future<void> _gerarEVisualizarPdfNotaFiscal(Map<String, dynamic> item) async {
    final pdf = pw.Document();

    final String nfNumero = item['nf_numero']?.toString() ?? 'N/A';
    final String nfChave = item['nf_chave_verificacao']?.toString() ?? 'N/A';
    final String descricao = item['descricao']?.toString() ?? 'Lançamento Financeiro';
    final bool isEntrada = item['tipo'] == 'ENTRADA';
    
    double valor = 0.0;
    if (item['valor'] is num) {
      valor = (item['valor'] as num).toDouble();
    } else {
      valor = double.tryParse(item['valor']?.toString() ?? '0') ?? 0.0;
    }

    String dataEmissaoFormatada = 'Recentemente';
    if (item['nf_data_emissao'] != null) {
      try {
        DateTime dt = DateTime.parse(item['nf_data_emissao'].toString());
        dataEmissaoFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isEntrada ? 'NOTA FISCAL DE ENTRADA' : 'COMPROVANTE / NOTA FISCAL DE SAÍDA',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    nfNumero,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.grey400),
              pw.SizedBox(height: 20),
              pw.Text('Chave de Verificação / Documento:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(nfChave, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text('Data de Emissão:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(dataEmissaoFormatada, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Text('Descrição:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(descricao, style: const pw.TextStyle(fontSize: 12))),
                    pw.Text('R\$ ${valor.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('VALOR: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${valor.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'NotaFiscal_$nfNumero.pdf',
    );
  }

  // Modal Adaptado para Entradas e Saídas
  void _abrirModalDetalhesLancamento(Map<String, dynamic> item) {
    final bool temNota = item['nf_numero'] != null && item['nf_numero'].toString().isNotEmpty;
    final bool isEntrada = item['tipo'] == 'ENTRADA';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEntrada ? 'Detalhes da Entrada / Nota Fiscal' : 'Detalhes da Saída / Nota Fiscal',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Descrição: ${item['descricao'] ?? 'Lançamento'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    if (temNota) ...[
                      // CASO POSSUA NOTA FISCAL CADASTRADA (Exibe dados e opção de visualizar)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NF Número: ${item['nf_numero']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Chave / Documento: ${item['nf_chave_verificacao'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _gerarEVisualizarPdfNotaFiscal(item),
                          child: const Text('Visualizar Nota Fiscal', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      // CASO NÃO POSSUA NOTA FISCAL CADASTRADA (Exibe a mensagem solicitada e opção de registar)
                      const Text(
                        'Nenhuma nota fiscal registrada.',
                        style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE4C47A),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () async {
                            try {
                              final randomNum = Random().nextInt(89999) + 10000;
                              final novoNumeroNF = 'NF-SAIDA-$randomNum';
                              final novaChave = 'DOC${Random().nextInt(999999999).toString().padLeft(6, '0')}';
                              final dataEmissao = DateTime.now().toIso8601String();

                              final resposta = await _supabase
                                  .from('lancamentos_financeiros')
                                  .update({
                                    'nf_numero': novoNumeroNF,
                                    'nf_chave_verificacao': novaChave,
                                    'nf_data_emissao': dataEmissao,
                                  })
                                  .eq('id', item['id'])
                                  .select();

                              if (mounted && resposta.isNotEmpty) {
                                Navigator.pop(context);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nota fiscal de saída registrada com sucesso!')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao registar nota: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Registar Nota Fiscal', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE4C47A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
          isDense: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4),
      body: Column(
        children: [
          // 1. CABEÇALHO
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            color: const Color(0xFFF0DCA7),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 28, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _nomeProfissional,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.reply, size: 30, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. BANNER DE TÍTULO
          Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE4C47A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black26, width: 1),
            ),
            child: const Text(
              'Relatório',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. CARTÃO PRINCIPAL
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 14),

                  // FILTROS SUPERIORES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDropdownFilter(
                          value: _filtroPeriodo,
                          items: [
                            'Período',
                            'Mês Atual',
                            'Ano Atual',
                            if (_filtroPeriodo != 'Período' &&
                                _filtroPeriodo != 'Mês Atual' &&
                                _filtroPeriodo != 'Ano Atual')
                              _filtroPeriodo,
                            'Escolher Datas...',
                          ],
                          onChanged: (v) {
                            if (v == 'Escolher Datas...') {
                              _selecionarIntervaloDatas();
                            } else if (v != null) {
                              setState(() {
                                _filtroPeriodo = v;
                                _intervaloDatasPersonalizado = null;
                              });
                            }
                          },
                        ),
                        _buildDropdownFilter(
                          value: _filtroDias,
                          items: ['7 dias', '15 dias', '30 dias', 'Todos'],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _filtroDias = v;
                                _filtroPeriodo = 'Período';
                                _intervaloDatasPersonalizado = null;
                              });
                            }
                          },
                        ),
                        _buildDropdownFilter(
                          value: _filtroFrequencia,
                          items: ['Diário', 'Semanal', 'Mensal'],
                          onChanged: (v) {
                            if (v != null) setState(() => _filtroFrequencia = v);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CABEÇALHO DA TABELA
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 45,
                          child: Text('Data', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Text('Descrição', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        Text('Valor (R\$)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Divider(color: Colors.black26, height: 1),
                  ),

                  // LISTAGEM DE LANÇAMENTOS
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buscarLancamentosRelatorio(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE4C47A)),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(child: Text('Erro ao carregar relatório.'));
                        }

                        final lista = snapshot.data ?? [];

                        if (lista.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nenhum lançamento encontrado.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          );
                        }

                        // Calcular saldo total do período listado
                        double saldoTotal = 0.0;
                        for (var item in lista) {
                          final double val = (item['valor'] is num)
                              ? (item['valor'] as num).toDouble()
                              : double.tryParse(item['valor'].toString()) ?? 0.0;
                          if (item['tipo'] == 'ENTRADA') {
                            saldoTotal += val;
                          } else {
                            saldoTotal -= val;
                          }
                        }

                        return Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: lista.length,
                                itemBuilder: (context, index) {
                                  final item = lista[index];

                                  String diaMes = '--/--';
                                  if (item['created_at'] != null) {
                                    try {
                                      DateTime dt = DateTime.parse(item['created_at'].toString());
                                      diaMes = '${dt.day}\n${_obterSiglaMes(dt.month)}';
                                    } catch (_) {}
                                  }

                                  final double valor = (item['valor'] is num)
                                      ? (item['valor'] as num).toDouble()
                                      : double.tryParse(item['valor'].toString()) ?? 0.0;

                                  final bool isEntrada = item['tipo'] == 'ENTRADA';
                                  final String tipoStr = isEntrada ? 'Pix Recebido' : 'Pix Enviado';
                                  final String descricaoServico = item['descricao'] ?? 'Serviço';
                                  
                                  final String linhaDescricao = 'Des: $descricaoServico';
                                  final String linhaDocumento = item['nf_numero'] != null 
                                      ? 'Documento ${item['nf_numero']}' 
                                      : (item['nf_chave_verificacao'] ?? 'Documento --');

                                  final double valorFinal = isEntrada ? valor : -valor;

                                  return InkWell(
                                    onTap: () => _abrirModalDetalhesLancamento(item),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              diaMes,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 24,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  margin: const EdgeInsets.only(top: 4),
                                                  decoration: BoxDecoration(
                                                    color: isEntrada ? Colors.green : Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Container(width: 1.5, color: Colors.black26),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tipoStr,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    linhaDescricao,
                                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                  ),
                                                  Text(
                                                    linhaDocumento,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '${valorFinal < 0 ? '-' : ''}${currencyFormatter.format(valorFinal.abs())}',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isEntrada ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Text('>', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // RODAPÉ COM SALDO DO DIA / PERÍODO
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.black26)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Saldo do dia',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  Text(
                                    currencyFormatter.format(saldoTotal),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _obterSiglaMes(int mes) {
    const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return meses[mes - 1];
  }
}