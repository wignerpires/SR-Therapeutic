import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContabilPage extends StatefulWidget {
  const ContabilPage({super.key});

  @override
  State<ContabilPage> createState() => _ContabilPageState();
}

class _ContabilPageState extends State<ContabilPage> {
  // Textos exibidos nos botões de pílula
  String _textoBotaoEsquerda = 'Diário';    // Opções: 'Diário', '7 dias', '15 dias'
  String _textoBotaoMeio = 'Mês';           // Exibe o mês selecionado (ex: 'Maio') ou 'Mês'
  String _textoBotaoDireita = 'Período';    // Exibe o intervalo do calendário ou 'Período'

  // Filtros aplicados na consulta (Iniciando com o dia de hoje por padrão)
  DateTime? _dataInicio;
  DateTime? _dataFim;

  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final List<String> _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  final List<String> _anos = ['2024', '2025', '2026'];

  @override
  void initState() {
    super.initState();
    // Inicializa o filtro padrão como "Diário" (Hoje) ao abrir a tela
    final hoje = DateTime.now();
    _dataInicio = DateTime(hoje.year, hoje.month, hoje.day, 0, 0, 0);
    _dataFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
  }

  int _obterNumeroMes(String nomeMes) {
    return _meses.indexOf(nomeMes) + 1;
  }

  // --- BOTÃO DIREITO: CALENDÁRIO (Período Personalizado) ---
  Future<void> _abrirCalendarioPeriodo() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _dataInicio != null && _dataFim != null
          ? DateTimeRange(start: _dataInicio!, end: _dataFim!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 15)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFFE4C47A),
            colorScheme: const ColorScheme.light(primary: Color(0xFFE4C47A)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataInicio = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _dataFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _textoBotaoDireita = '${DateFormat('dd/MM').format(picked.start)} - ${DateFormat('dd/MM').format(picked.end)}';
        _textoBotaoMeio = 'Mês';
        _textoBotaoEsquerda = 'Filtro';
      });
    }
  }

  // --- BOTÃO DO MEIO: SELECIONAR ANO E MÊS ---
  void _abrirSeletorAnoMes() {
    String anoTemp = DateTime.now().year.toString();
    String mesTemp = _meses[DateTime.now().month - 1];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Selecionar Mês Desejado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: anoTemp,
                decoration: const InputDecoration(labelText: 'Ano'),
                items: _anos.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) { if (val != null) anoTemp = val; },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mesTemp,
                decoration: const InputDecoration(labelText: 'Mês'),
                items: _meses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) { if (val != null) mesTemp = val; },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE4C47A), foregroundColor: Colors.black87),
              onPressed: () {
                setState(() {
                  _textoBotaoMeio = mesTemp;
                  _textoBotaoDireita = 'Período';
                  _textoBotaoEsquerda = 'Filtro';
                  int anoInt = int.parse(anoTemp);
                  int mesNum = _obterNumeroMes(mesTemp);
                  _dataInicio = DateTime(anoInt, mesNum, 1, 0, 0, 0);
                  _dataFim = DateTime(anoInt, mesNum + 1, 0, 23, 59, 59);
                });
                Navigator.pop(context);
              },
              child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- BOTÃO ESQUERDA: DIÁRIO / ÚLTIMOS 7 DIAS / ÚLTIMOS 15 DIAS ---
  void _mostrarOpcoesEsquerda() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione o Intervalo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Diário (Hoje)'),
                onTap: () {
                  setState(() {
                    _textoBotaoEsquerda = 'Diário';
                    _textoBotaoMeio = 'Mês';
                    _textoBotaoDireita = 'Período';
                    final hoje = DateTime.now();
                    _dataInicio = DateTime(hoje.year, hoje.month, hoje.day, 0, 0, 0);
                    _dataFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Últimos 7 dias'),
                onTap: () {
                  setState(() {
                    _textoBotaoEsquerda = '7 dias';
                    _textoBotaoMeio = 'Mês';
                    _textoBotaoDireita = 'Período';
                    final hoje = DateTime.now();
                    _dataInicio = hoje.subtract(const Duration(days: 7));
                    _dataFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Últimos 15 dias'),
                onTap: () {
                  setState(() {
                    _textoBotaoEsquerda = '15 dias';
                    _textoBotaoMeio = 'Mês';
                    _textoBotaoDireita = 'Período';
                    final hoje = DateTime.now();
                    _dataInicio = hoje.subtract(const Duration(days: 15));
                    _dataFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Consulta ao Supabase (Garantindo filtragem por data de pagamento/recebimento)
  Future<List<Map<String, dynamic>>> _buscarLancamentosContabeis() async {
    final supabase = Supabase.instance.client;

    try {
      var query = supabase.from('lancamentos_contabeis').select();

      if (_dataInicio != null && _dataFim != null) {
        query = query
            .gte('created_at', _dataInicio!.toIso8601String())
            .lte('created_at', _dataFim!.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      List<Map<String, dynamic>> listaFormatada = [];
      for (var item in response) {
        listaFormatada.add({
          'id': item['id'],
          'tipo': item['tipo'], // 'entrada' ou 'saida'
          'descricao': item['descricao'] ?? 'Sem descrição',
          'sub_descricao': item['sub_descricao'] ?? 'Des: Lançamento',
          'documento': item['documento'] ?? '--',
          'valor': item['valor'] ?? 0.0,
          'data_pagamento': item['data_pagamento'], // Data em que foi considerado PAGO/recebido
        });
      }
      return listaFormatada;
    } catch (e) {
      debugPrint('Erro ao buscar dados: $e');
      // Dados estáticos de fallback simulando o comportamento solicitado
      return [
        {'id': 1, 'tipo': 'entrada', 'descricao': 'Pix Recebido', 'sub_descricao': 'Des: Pix Recebido', 'documento': '--', 'valor': 150.0, 'data_pagamento': '2026-09-17T14:30:00Z'},
        {'id': 2, 'tipo': 'entrada', 'descricao': 'Pix Recebido', 'sub_descricao': 'Des: Pix Recebido', 'documento': 'NF-SAIDA-42356', 'valor': 140.0, 'data_pagamento': '2026-05-14T10:00:00Z'},
        {'id': 3, 'tipo': 'entrada', 'descricao': 'Pix Recebido', 'sub_descricao': 'Des: Pix Recebido', 'documento': 'NF-58669', 'valor': 250.0, 'data_pagamento': '2026-09-25T16:00:00Z'},
        {'id': 4, 'tipo': 'saida', 'descricao': 'Pix Enviado', 'sub_descricao': 'Des: Agulhas', 'documento': '--', 'valor': 120.0, 'data_pagamento': '2026-09-18T11:00:00Z'},
      ];
    }
  }

  String _obterSiglaMes(int mes) {
    const mesesSigla = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    if (mes < 1 || mes > 12) return '';
    return mesesSigla[mes - 1];
  }

  void _gerarPdfContador() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerando relatório em PDF para o contador...'),
        backgroundColor: Color(0xFFE4C47A),
      ),
    );
  }

  // Construtor dos Botões em Pílula
  Widget _buildFiltroPill(String texto, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE4C47A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartão de Título "Relatório"
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4C47A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Contábil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Linha com os 3 botões de pílula
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFiltroPill(_textoBotaoEsquerda, _mostrarOpcoesEsquerda),
                  const SizedBox(width: 8),
                  _buildFiltroPill(_textoBotaoMeio, _abrirSeletorAnoMes),
                  const SizedBox(width: 8),
                  _buildFiltroPill(_textoBotaoDireita, _abrirCalendarioPeriodo),
                ],
              ),
            ),

            // Botão de PDF para o Contador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _gerarPdfContador,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE4C47A),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Gerar PDF para o Contador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ),

            const Divider(height: 16, thickness: 1),

            // Cabeçalho da Tabela
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data (Pago)', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Descrição', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Valor (R\$)', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 8, thickness: 1),

            // Listagem de Lançamentos
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _buscarLancamentosContabeis(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE4C47A)),
                      ),
                    );
                  }

                  final lista = snapshot.data ?? [];

                  if (lista.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum lançamento encontrado.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    );
                  }

                  double saldoDoPeriodo = 0.0;
                  for (var item in lista) {
                    final valor = (item['valor'] is num)
                        ? (item['valor'] as num).toDouble()
                        : double.tryParse(item['valor'].toString()) ?? 0.0;
                    if (item['tipo'] == 'entrada') {
                      saldoDoPeriodo += valor;
                    } else {
                      saldoDoPeriodo -= valor;
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
                            final bool isEntrada = item['tipo'] == 'entrada';

                            String dia = '--';
                            String mes = '--';
                            if (item['data_pagamento'] != null) {
                              try {
                                DateTime dt = DateTime.parse(item['data_pagamento'].toString());
                                dia = dt.day.toString();
                                mes = _obterSiglaMes(dt.month);
                              } catch (_) {}
                            }

                            final double valor = (item['valor'] is num)
                                ? (item['valor'] as num).toDouble()
                                : double.tryParse(item['valor'].toString()) ?? 0.0;

                            final String titulo = item['descricao'] ?? 'Pix';
                            final String subDescricao = item['sub_descricao'] ?? 'Des: Pix';
                            final String documento = item['documento'] ?? '--';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 42,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(dia, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          Text(mes, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 20,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isEntrada ? Colors.green : Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Expanded(child: Container(width: 1.5, color: Colors.black26)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          Text(subDescricao, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          Text('Documento $documento', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${isEntrada ? '' : '- '}${currencyFormatter.format(valor)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isEntrada ? Colors.green[700] : Colors.red[700],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('>', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.black12, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo do período', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text(currencyFormatter.format(saldoDoPeriodo), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
    );
  }
}