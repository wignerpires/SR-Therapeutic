import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MovimentacaoReembolsosPage extends StatefulWidget {
  const MovimentacaoReembolsosPage({super.key});

  @override
  State<MovimentacaoReembolsosPage> createState() => _MovimentacaoReembolsosPageState();
}

class _MovimentacaoReembolsosPageState extends State<MovimentacaoReembolsosPage> {
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

  // Abre o Seletor de Datas
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

  // Consulta das Entradas PAGAS no Supabase
  Future<List<Map<String, dynamic>>> _buscarEntradasParaReembolso() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    var query = _supabase
        .from('lancamentos_financeiros')
        .select()
        .eq('id_usuario', user.id)
        .eq('tipo', 'ENTRADA')
        .eq('status', 'PAGO'); // Filtra apenas entradas pagas

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

  // Modal para gerir (aplicar ou reverter) o reembolso
  void _abrirModalAplicarReembolso(Map<String, dynamic> item) {
    final double valorBase = (item['valor_original'] != null && item['valor_original'] != 0)
        ? double.parse(item['valor_original'].toString())
        : double.parse(item['valor'].toString());

    final double reembolsoAnterior = item['valor_reembolsado'] != null
        ? double.parse(item['valor_reembolsado'].toString())
        : 0.0;

    final txtValorReembolso = TextEditingController(
      text: reembolsoAnterior > 0 ? reembolsoAnterior.toStringAsFixed(2) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double valReembolsoDigitado =
                double.tryParse(txtValorReembolso.text.replaceAll(',', '.')) ?? 0.0;

            if (valReembolsoDigitado > valorBase) {
              valReembolsoDigitado = valorBase;
            }

            bool ehReembolsoTotal = (valReembolsoDigitado >= valorBase);
            double novoValorLiquido = valorBase - valReembolsoDigitado;

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
                      'Gerir Reembolso: ${item['descricao'] ?? 'Atendimento'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valor Original: R\$ ${valorBase.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: txtValorReembolso,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor a Reembolsar (R\$)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                ehReembolsoTotal ? 'Reembolso Total' : 'Reembolso Parcial',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ehReembolsoTotal ? Colors.red : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Novo Valor Líquido:', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                'R\$ ${novoValorLiquido.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // BOTÃO CONFIRMAR REEMBOLSO
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
                            final Map<String, dynamic> dadosAtualizacao = {
                              'valor_original': valorBase,
                              'valor_reembolsado': valReembolsoDigitado,
                              'valor': novoValorLiquido,
                              'data_reembolso': DateTime.now().toIso8601String(),
                              'status': 'PAGO',
                            };

                            final resposta = await _supabase
                                .from('lancamentos_financeiros')
                                .update(dadosAtualizacao)
                                .eq('id', item['id'])
                                .select();

                            if (mounted) {
                              if (resposta.isNotEmpty) {
                                Navigator.pop(context);
                                setState(() {});
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao atualizar: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Confirmar Reembolso', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    // BOTÃO REVERTER REEMBOLSO (Disponível caso já tenha reembolso aplicado)
                    if (reembolsoAnterior > 0) ...[
                      const SizedBox(height: 10),
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
                              final resposta = await _supabase
                                  .from('lancamentos_financeiros')
                                  .update({
                                    'valor_original': valorBase,
                                    'valor_reembolsado': 0.00,
                                    'valor': valorBase, // Restaura o valor integral original
                                    'data_reembolso': null,
                                    'status': 'PAGO',
                                  })
                                  .eq('id', item['id'])
                                  .select();

                              if (mounted) {
                                if (resposta.isNotEmpty) {
                                  Navigator.pop(context);
                                  setState(() {});
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao reverter: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Reverter Reembolso (Restaurar Valor)', style: TextStyle(fontWeight: FontWeight.bold)),
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
              'Reembolsos',
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
                        Text('Valor Líquido', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Divider(color: Colors.black26, height: 1),
                  ),

                  // LISTAGEM DE ATENDIMENTOS PAGOS
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buscarEntradasParaReembolso(),
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

                        double totalReembolsado = 0.0;
                        for (var item in lista) {
                          final reemb = item['valor_reembolsado'];
                          if (reemb != null) {
                            totalReembolsado += (reemb is num)
                                ? reemb.toDouble()
                                : double.tryParse(reemb.toString()) ?? 0.0;
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

                                  final double valorAtual = (item['valor'] is num)
                                      ? (item['valor'] as num).toDouble()
                                      : double.tryParse(item['valor'].toString()) ?? 0.0;

                                  final double valorReembolsado = (item['valor_reembolsado'] != null)
                                      ? (item['valor_reembolsado'] is num
                                          ? (item['valor_reembolsado'] as num).toDouble()
                                          : double.tryParse(item['valor_reembolsado'].toString()) ?? 0.0)
                                      : 0.0;

                                  final String descricao = item['descricao'] ?? 'Atendimento';

                                  return InkWell(
                                    onTap: () => _abrirModalAplicarReembolso(item),
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
                                                    color: valorReembolsado > 0 ? Colors.red : Colors.green,
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
                                                  if (valorReembolsado > 0)
                                                    Text(
                                                      'Reembolsado: R\$ ${valorReembolsado.toStringAsFixed(2)}',
                                                      style: const TextStyle(fontSize: 12, color: Colors.red),
                                                    )
                                                  else
                                                    const Text(
                                                      'Clique para solicitar reembolso',
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
                                                  currencyFormatter.format(valorAtual),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.currency_exchange, size: 20, color: Color(0xFFE4C47A)),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.black12, width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Reembolsado',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(totalReembolsado),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
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