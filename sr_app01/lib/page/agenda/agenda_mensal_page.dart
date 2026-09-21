import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/agenda/config_agenda_page.dart';

class AgendaMensalPage extends StatefulWidget {
  const AgendaMensalPage({super.key});

  @override
  State<AgendaMensalPage> createState() => _AgendaMensalPageState();
}

class _AgendaMensalPageState extends State<AgendaMensalPage> {
  DateTime _dataBaseMes = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;

  String _nomeProfissional = 'Carregando...';
  bool _carregandoDados = true;

  // Cache local dos dados do Supabase para o mês ativo
  Map<String, dynamic>? _configAgenda;
  List<dynamic> _agendamentosDoMes = [];

  final List<String> _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  final List<String> _diasDaSemanaRotulos = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _buscarNomeProfissional();
    await _buscarDadosMensais();
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
          setState(() {
            _nomeProfissional = dadosPerfil['nome'];
          });
        } else {
          setState(() => _nomeProfissional = 'Profissional');
        }
      }
    } catch (e) {
      setState(() => _nomeProfissional = 'Profissional');
    }
  }

  // Otimizado: Busca dados do mês inteiro de uma única vez
  Future<void> _buscarDadosMensais() async {
    setState(() => _carregandoDados = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Busca as regras globais de atendimento do profissional
      final config = await _supabase
          .from('config_agenda')
          .select()
          .eq('id_usuario', user.id)
          .maybeSingle();

      // 2. Calcula os limites de data inferior e superior para o mês atual
      String primeiroDiaIso = "${_dataBaseMes.year}-${_dataBaseMes.month.toString().padLeft(2, '0')}-01";
      int ultimoDiaInt = DateTime(_dataBaseMes.year, _dataBaseMes.month + 1, 0).day;
      String ultimoDiaIso = "${_dataBaseMes.year}-${_dataBaseMes.month.toString().padLeft(2, '0')}-$ultimoDiaInt";

      // 3. Filtra todos os agendamentos contidos neste intervalo específico
      final agendamentos = await _supabase
          .from('agendamentos')
          .select()
          .eq('id_usuario', user.id)
          .gte('data_agendamento', primeiroDiaIso)
          .lte('data_agendamento', ultimoDiaIso);

      setState(() {
        _configAgenda = config;
        _agendamentosDoMes = agendamentos;
      });
    } catch (e) {
      debugPrint('Erro ao buscar dados mensais: $e');
    } finally {
      setState(() => _carregandoDados = false);
    }
  }

  // Lógica dinâmica de coloração por dia baseada nas regras de negócio
  Color _calcularCorStatusDia(int dia) {
    if (_configAgenda == null) return Colors.red; // Sem config = Indisponível (Vermelho)

    // Instancia a data do dia corrente avaliado pelo Grid
    DateTime dataAvaliada = DateTime(_dataBaseMes.year, _dataBaseMes.month, dia);

    // 1. Verifica se o profissional atende neste dia da semana
    List<String> diasDaSemana = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'];
    String diaSemanaSigla = diasDaSemana[dataAvaliada.weekday % 7];
    bool atendeNesseDiaSemana = _configAgenda![diaSemanaSigla] ?? false;

    if (!atendeNesseDiaSemana) return Colors.red; // Não trabalha no dia = Vermelho

    // 2. Filtra agendamentos correspondentes estritamente a este dia
    String dataAvaliadaIso = dataAvaliada.toIso8601String().substring(0, 10);
    var agendamentosDoDia = _agendamentosDoMes.where((agendamento) {
      return agendamento['data_agendamento'] == dataAvaliadaIso;
    }).toList();

    // 3. Se houver qualquer agendamento confirmado no dia, o status passa a ser Ocupado (Azul)
    if (agendamentosDoDia.isNotEmpty) {
      return Colors.blue;
    }

    // 4. Se trabalha no dia e não possui marcações, o dia está completamente Livre (Verde)
    return Colors.green;
  }

  void _avancarMes() {
    setState(() {
      _dataBaseMes = DateTime(_dataBaseMes.year, _dataBaseMes.month + 1, 1);
    });
    _buscarDadosMensais();
  }

  void _retrocederMes() {
    setState(() {
      _dataBaseMes = DateTime(_dataBaseMes.year, _dataBaseMes.month - 1, 1);
    });
    _buscarDadosMensais();
  }

  @override
  Widget build(BuildContext context) {
    int totalDiasNoMes = DateTime(_dataBaseMes.year, _dataBaseMes.month + 1, 0).day;
    int primeiroDiaSemanaIndex = DateTime(_dataBaseMes.year, _dataBaseMes.month, 1).weekday;
    int espacosVaziosNoInicio = primeiroDiaSemanaIndex == 7 ? 0 : primeiroDiaSemanaIndex;
    int totalItensGrid = espacosVaziosNoInicio + totalDiasNoMes;
    
    if (totalItensGrid % 7 != 0) {
      totalItensGrid += (7 - (totalItensGrid % 7));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4),
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/ondas_douradas.png',
              fit: BoxFit.cover,
            ),
          ),
          
          Column(
            children: [
              // 1. CABEÇALHO PADRÃO
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: const Color(0xFFF0DCA7),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 30, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nomeProfissional,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.black),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.reply, size: 32, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // 2. TÍTULO DA TELA
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Angenda Mensal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 16),

              // 3. SELETOR DINÂMICO DE MÊS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D9B84),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 24, color: Colors.black),
                        onPressed: _retrocederMes,
                      ),
                      Expanded(
                        child: Text(
                          "Mês de ${_meses[_dataBaseMes.month - 1]} de ${_dataBaseMes.year}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.black),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 24, color: Colors.black),
                        onPressed: _avancarMes,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. CALENDÁRIO COMPLETO NO PAINEL BRANCO
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                    child: _carregandoDados
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFC5993F),
                            ),
                          )
                        : Column(
                            children: [
                              // Rótulos estruturais (Dom, Seg, Ter...)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: _diasDaSemanaRotulos.map((rotulo) {
                                  return Expanded(
                                    child: Text(
                                      rotulo,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              
                              // Grid numérico mapeado do Supabase
                              Expanded(
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: totalItensGrid,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 6,
                                    childAspectRatio: 0.65,
                                  ),
                                  itemBuilder: (context, index) {
                                    int diaNumero = index - espacosVaziosNoInicio + 1;
                                    
                                    // Renderiza blocos opacos vazios caso pertençam ao mês anterior/posterior
                                    if (index < espacosVaziosNoInicio || diaNumero > totalDiasNoMes) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9CC9BC).withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black.withOpacity(0.3), width: 0.5),
                                        ),
                                      );
                                    }

                                    String diaFormatado = diaNumero < 10 ? "0$diaNumero" : "$diaNumero";
                                    final Color corStatusReal = _calcularCorStatusDia(diaNumero);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9CC9BC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.black, width: 0.8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            diaFormatado,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Colors.black),
                                          ),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: corStatusReal,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.black, width: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. BOTÃO INFERIOR DE CONFIGURAÇÕES
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Aguarda o retorno da tela de configurações para invalidar o cache antigo e atualizar o grid
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfigAgendaPage()),
                      );
                      _buscarDadosMensais();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5993F),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black, width: 1),
                      ),
                    ),
                    child: const Text(
                      'Configurações de agenda',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}