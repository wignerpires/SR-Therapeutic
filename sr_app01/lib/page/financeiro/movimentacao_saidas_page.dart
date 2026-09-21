import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MovimentacaoSaidasPage extends StatefulWidget {
  const MovimentacaoSaidasPage({super.key});

  @override
  State<MovimentacaoSaidasPage> createState() => _MovimentacaoSaidasPageState();
}

class _MovimentacaoSaidasPageState extends State<MovimentacaoSaidasPage> {
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

  // Consulta das SAÍDAS no Supabase
  Future<List<Map<String, dynamic>>> _buscarSaidasFinanceiras() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    var query = _supabase
        .from('lancamentos_financeiros')
        .select()
        .eq('id_usuario', user.id)
        .eq('tipo', 'SAIDA') // Filtra apenas SAÍDAS
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

      query = query.gte('data_competencia', inicioIso).lte('data_competencia', fimIso);
    } else if (_filtroPeriodo == 'Mês Atual') {
      final inicioMes = DateTime(agora.year, agora.month, 1);
      query = query.gte('data_competencia', inicioMes.toIso8601String());
    } else if (_filtroPeriodo == 'Ano Atual') {
      final inicioAno = DateTime(agora.year, 1, 1);
      query = query.gte('data_competencia', inicioAno.toIso8601String());
    } else {
      int? diasAtras;
      if (_filtroDias == '7 dias') diasAtras = 7;
      if (_filtroDias == '15 dias') diasAtras = 15;
      if (_filtroDias == '30 dias') diasAtras = 30;

      if (diasAtras != null) {
        final dataInicio = agora.subtract(Duration(days: diasAtras));
        query = query.gte('data_competencia', dataInicio.toIso8601String());
      }
    }

    final response = await query.order('data_competencia', ascending: false);
    final List<Map<String, dynamic>> registrosBrutos = List<Map<String, dynamic>>.from(response);

    if (_filtroFrequencia == 'Diário') return registrosBrutos;
    if (_filtroFrequencia == 'Mensal') return _agruparPorMes(registrosBrutos);
    if (_filtroFrequencia == 'Semanal') return _agruparPorSemana(registrosBrutos);

    return registrosBrutos;
  }

  List<Map<String, dynamic>> _agruparPorMes(List<Map<String, dynamic>> lista) {
    final Map<String, Map<String, dynamic>> agrupado = {};

    for (var item in lista) {
      if (item['data_competencia'] == null) continue;
      final dt = DateTime.parse(item['data_competencia'].toString());
      final chaveMes = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

      final double valor = (item['valor'] is num)
          ? (item['valor'] as num).toDouble()
          : double.tryParse(item['valor'].toString()) ?? 0.0;

      if (!agrupado.containsKey(chaveMes)) {
        agrupado[chaveMes] = {
          'data_competencia': dt.toIso8601String(),
          'descricao': 'Total de Saídas (${_obterSiglaMes(dt.month)}/${dt.year})',
          'subdescricao': 'Agrupado por mês',
          'documento_ref': null,
          'valor': valor,
        };
      } else {
        agrupado[chaveMes]!['valor'] = (agrupado[chaveMes]!['valor'] as double) + valor;
      }
    }

    return agrupado.values.toList();
  }

  List<Map<String, dynamic>> _agruparPorSemana(List<Map<String, dynamic>> lista) {
    final Map<String, Map<String, dynamic>> agrupado = {};

    for (var item in lista) {
      if (item['data_competencia'] == null) continue;
      final dt = DateTime.parse(item['data_competencia'].toString());
      final inicioSemana = dt.subtract(Duration(days: dt.weekday - 1));
      final chaveSemana = '${inicioSemana.year}-${inicioSemana.month}-${inicioSemana.day}';

      final double valor = (item['valor'] is num)
          ? (item['valor'] as num).toDouble()
          : double.tryParse(item['valor'].toString()) ?? 0.0;

      if (!agrupado.containsKey(chaveSemana)) {
        agrupado[chaveSemana] = {
          'data_competencia': inicioSemana.toIso8601String(),
          'descricao': 'Semana de ${inicioSemana.day}/${inicioSemana.month}',
          'subdescricao': 'Agrupado por semana',
          'documento_ref': null,
          'valor': valor,
        };
      } else {
        agrupado[chaveSemana]!['valor'] = (agrupado[chaveSemana]!['valor'] as double) + valor;
      }
    }

    return agrupado.values.toList();
  }

  // Modal para cadastrar nova Saída manual
  void _abrirModalNovaSaida() {
    final txtDescricao = TextEditingController();
    final txtSubdescricao = TextEditingController();
    final txtValor = TextEditingController();
    final txtDocRef = TextEditingController();
    DateTime dataSelecionada = DateTime.now();

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
                    const Text(
                      'Nova Saída',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: txtDescricao,
                      decoration: const InputDecoration(
                        labelText: 'Descrição *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: txtSubdescricao,
                      decoration: const InputDecoration(
                        labelText: 'Subdescrição / Categoria',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: txtValor,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Valor (R\$) *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: txtDocRef,
                            decoration: const InputDecoration(
                              labelText: 'Doc. Ref.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Data: ${DateFormat('dd/MM/yyyy').format(dataSelecionada)}'),
                      trailing: const Icon(Icons.calendar_today, color: Color(0xFFE4C47A)),
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          locale: const Locale('pt', 'BR'),
                          initialDate: dataSelecionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (dt != null) {
                          setModalState(() => dataSelecionada = dt);
                        }
                      },
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
                          final desc = txtDescricao.text.trim();
                          final valStr = txtValor.text.replaceAll(',', '.').trim();

                          if (desc.isEmpty || valStr.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Preencha os campos obrigatórios.')),
                            );
                            return;
                          }

                          final double? valor = double.tryParse(valStr);
                          if (valor == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Valor inválido.')),
                            );
                            return;
                          }

                          try {
                            final user = _supabase.auth.currentUser;
                            if (user == null) return;

                            await _supabase.from('lancamentos_financeiros').insert({
                              'id_usuario': user.id,
                              'descricao': desc,
                              'subdescricao': txtSubdescricao.text.trim(),
                              'documento_ref': txtDocRef.text.trim().isEmpty ? null : txtDocRef.text.trim(),
                              'valor': valor,
                              'tipo': 'SAIDA',
                              'status': 'PAGO',
                              'data_competencia': dataSelecionada.toIso8601String(),
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {}); // Recarrega a listagem
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erro ao registrar saída.')),
                              );
                            }
                          }
                        },
                        child: const Text('Salvar Saída', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
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
      // BOTÃO FLUTUANTE PARA ADICIONAR SAÍDAS
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE4C47A),
        foregroundColor: Colors.black,
        elevation: 4,
        onPressed: _abrirModalNovaSaida,
        child: const Icon(Icons.add, size: 30),
      ),
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
              'Saídas',
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

                  // LISTAGEM DE SAÍDAS
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buscarSaidasFinanceiras(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE4C47A)),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Erro ao carregar os lançamentos de saída.'),
                          );
                        }

                        final lista = snapshot.data ?? [];

                        if (lista.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nenhuma saída encontrada para este período.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          );
                        }

                        double totalSaidas = 0.0;
                        for (var item in lista) {
                          final v = item['valor'];
                          if (v != null) {
                            totalSaidas += (v is num) ? v.toDouble() : double.parse(v.toString());
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
                                  if (item['data_competencia'] != null) {
                                    try {
                                      DateTime dt = DateTime.parse(item['data_competencia'].toString());
                                      diaMes = '${dt.day}\n${_obterSiglaMes(dt.month)}';
                                    } catch (_) {}
                                  }

                                  final double valor = (item['valor'] is num)
                                      ? (item['valor'] as num).toDouble()
                                      : double.tryParse(item['valor'].toString()) ?? 0.0;

                                  final String descricao = item['descricao'] ?? 'Saída';
                                  final String subdescricao = item['subdescricao'] ?? '';
                                  final String docRef = item['documento_ref'] != null
                                      ? 'Documento ${item['documento_ref']}'
                                      : '';

                                  return IntrinsicHeight(
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
                                              // Indicador visual vermelho para Saídas
                                              Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.only(top: 4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  width: 1.5,
                                                  color: Colors.black26,
                                                ),
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
                                                if (subdescricao.isNotEmpty)
                                                  Text(
                                                    subdescricao,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                if (docRef.isNotEmpty)
                                                  Text(
                                                    docRef,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
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
                                                  color: Colors.red, // Cor vermelha para indicar saída
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                    'Total de saídas',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(totalSaidas),
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