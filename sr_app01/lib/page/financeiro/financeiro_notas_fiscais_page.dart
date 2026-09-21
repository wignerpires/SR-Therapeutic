import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class FinanceiroNotasFiscaisPage extends StatefulWidget {
  const FinanceiroNotasFiscaisPage({super.key});

  @override
  State<FinanceiroNotasFiscaisPage> createState() => _FinanceiroNotasFiscaisPageState();
}

class _FinanceiroNotasFiscaisPageState extends State<FinanceiroNotasFiscaisPage> {
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

  // Busca apenas entradas pagas para gerir/emitir notas fiscais
  Future<List<Map<String, dynamic>>> _buscarAtendimentosParaNF() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    var query = _supabase
        .from('lancamentos_financeiros')
        .select()
        .eq('id_usuario', user.id)
        .eq('tipo', 'ENTRADA')
        .eq('status', 'PAGO');

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

  // Função para gerar e visualizar o PDF da Nota Fiscal
  Future<void> _gerarEVisualizarPdfNotaFiscal(Map<String, dynamic> item) async {
    final pdf = pw.Document();

    final String nfNumero = item['nf_numero']?.toString() ?? 'N/A';
    final String nfChave = item['nf_chave_verificacao']?.toString() ?? 'N/A';
    final String descricao = item['descricao']?.toString() ?? 'Serviço Prestado';
    
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
              // Cabeçalho da Nota
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NOTA FISCAL DE SERVIÇOS (Simulada)',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    nfNumero,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.grey400),
              pw.SizedBox(height: 20),

              // Informações da Chave e Emissão
              pw.Text('Chave de Verificação:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(nfChave, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text('Data de Emissão:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(dataEmissaoFormatada, style: const pw.TextStyle(fontSize: 12)),
              
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Descrição do Serviço
              pw.Text('Discriminação dos Serviços:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
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

              // Total da Nota
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('VALOR TOTAL: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${valor.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Abre a pré-visualização para exportar, partilhar ou imprimir o PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'NotaFiscal_$nfNumero.pdf',
    );
  }

  // Modal para Gerir ou Emitir a Nota Fiscal simulada
  void _abrirModalNotaFiscal(Map<String, dynamic> item) {
    final bool temNota = item['nf_numero'] != null && item['nf_numero'].toString().isNotEmpty;
    
    String nfNumero = temNota ? item['nf_numero'].toString() : '';
    String nfChave = temNota ? item['nf_chave_verificacao'].toString() : '';

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
                      temNota ? 'Nota Fiscal Emitida' : 'Emitir Nota Fiscal (Simulada)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Atendimento: ${item['descricao'] ?? 'Serviço'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    if (temNota) ...[
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
                            Text('NF Número: $nfNumero', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Chave de Verificação: $nfChave', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              item['nf_data_emissao'] != null 
                                ? 'Emitida em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['nf_data_emissao']))}'
                                : 'Emitida recentemente', 
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Botão para Visualizar / Descarregar PDF
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _gerarEVisualizarPdfNotaFiscal(item);
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf),
                              SizedBox(width: 8),
                              Text('Visualizar / Descarregar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () async {
                            try {
                              await _supabase.from('lancamentos_financeiros').update({
                                'nf_numero': null,
                                'nf_chave_verificacao': null,
                                'nf_data_emissao': null,
                              }).eq('id', item['id']);

                              if (mounted) {
                                Navigator.pop(context);
                                setState(() {});
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao cancelar nota: $e')),
                              );
                            }
                          },
                          child: const Text('Cancelar / Remover Nota Fiscal', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Ao confirmar, será gerada uma Nota Fiscal eletrônica simulada para este lançamento financeiro.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
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
                              final novoNumeroNF = 'NF-$randomNum';
                              final novaChave = '3526${Random().nextInt(999999999).toString().padLeft(9, '0')}';
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

                              if (mounted) {
                                if (resposta.isNotEmpty) {
                                  Navigator.pop(context);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Nota Fiscal gerada com sucesso!')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao emitir nota: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Gerar e Anexar Nota Fiscal', style: TextStyle(fontWeight: FontWeight.bold)),
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
          // 1. CABEÇALHO DOURADO
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
              'Nota Fiscal',
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
                          child: Text('Descrição / NF', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        Text('Valor', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Divider(color: Colors.black26, height: 1),
                  ),

                  // LISTAGEM
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buscarAtendimentosParaNF(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE4C47A)),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(child: Text('Erro ao carregar atendimentos.'));
                        }

                        final lista = snapshot.data ?? [];

                        if (lista.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nenhum atendimento pago encontrado.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          );
                        }

                        return ListView.builder(
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

                            final String descricao = item['descricao'] ?? 'Serviço';
                            final bool temNota = item['nf_numero'] != null && item['nf_numero'].toString().isNotEmpty;
                            final String numeroNF = temNota ? item['nf_numero'].toString() : '';

                            return InkWell(
                              onTap: () => _abrirModalNotaFiscal(item),
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
                                              color: temNota ? Colors.blue : Colors.grey,
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
                                              descricao,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (temNota)
                                              Text(
                                                'NF: $numeroNF',
                                                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                              )
                                            else
                                              const Text(
                                                'Clique para emitir Nota Fiscal',
                                                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                            currencyFormatter.format(valor),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            temNota ? Icons.receipt_long : Icons.note_add,
                                            size: 20,
                                            color: temNota ? Colors.blue : const Color(0xFFE4C47A),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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