import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/agenda/config_agenda_page.dart';

class AgendaSemanalPage extends StatefulWidget {
  const AgendaSemanalPage({super.key});

  @override
  State<AgendaSemanalPage> createState() => _AgendaSemanalPageState();
}

class _AgendaSemanalPageState extends State<AgendaSemanalPage> {
  DateTime _dataBaseSemana = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;

  String _nomeProfissional = 'Carregando...';
  bool _carregandoDados = true;

  // Cache local dos dados obtidos do Supabase para a semana ativa
  Map<String, dynamic>? _configAgenda;
  List<dynamic> _agendamentosDaSemana = [];

  final List<String> _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
  ];

  // Nomes dos dias estruturados sequencialmente (Domingo = index 0)
  final List<String> _diasNomes = [
    'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'
  ];

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _buscarNomeProfissional();
    await _buscarDadosSemanais();
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

  // Busca centralizada de todas as informações da semana ativa
  Future<void> _buscarDadosSemanais() async {
    setState(() => _carregandoDados = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Busca as regras globais de dias de atendimento
      final config = await _supabase
          .from('config_agenda')
          .select()
          .eq('id_usuario', user.id)
          .maybeSingle();

      // 2. Calcula as datas exatas de início (domingo) e fim (sábado) desta semana
      int diasDesdeDomingo = _dataBaseSemana.weekday == 7 ? 0 : _dataBaseSemana.weekday;
      DateTime primeiroDiaSemana = _dataBaseSemana.subtract(Duration(days: diasDesdeDomingo));
      DateTime ultimoDiaSemana = primeiroDiaSemana.add(const Duration(days: 6));

      String dataInicioIso = primeiroDiaSemana.toIso8601String().substring(0, 10);
      String dataFimIso = ultimoDiaSemana.toIso8601String().substring(0, 10);

      // 3. Busca todos os agendamentos contidos estritamente nesse intervalo
      final agendamentos = await _supabase
          .from('agendamentos')
          .select()
          .eq('id_usuario', user.id)
          .gte('data_agendamento', dataInicioIso)
          .lte('data_agendamento', dataFimIso);

      setState(() {
        _configAgenda = config;
        _agendamentosDaSemana = agendamentos;
      });
    } catch (e) {
      debugPrint('Erro ao buscar dados semanais: $e');
    } finally {
      setState(() => _carregandoDados = false);
    }
  }

  // Resolve dinamicamente o status do dia para popular o bloco da lista
  Map<String, dynamic> _calcularStatusDoDia(int indexDaSemana) {
    // Se não houver configuração salva, o padrão de segurança é indisponível
    if (_configAgenda == null) {
      return {'status': 'Indisponível', 'cor': const Color(0xFFD9534F)};
    }

    // Calcula a data real correspondente ao dia da linha avaliada
    int diasDesdeDomingo = _dataBaseSemana.weekday == 7 ? 0 : _dataBaseSemana.weekday;
    DateTime primeiroDiaSemana = _dataBaseSemana.subtract(Duration(days: diasDesdeDomingo));
    DateTime dataAlvo = primeiroDiaSemana.add(Duration(days: indexDaSemana));

    // 1. Verifica se atende nesse dia da semana (mapeamento de siglas no banco)
    List<String> siglasDias = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'];
    bool atendeNesseDia = _configAgenda![siglasDias[indexDaSemana]] ?? false;

    if (!atendeNesseDia) {
      return {'status': 'Indisponível', 'cor': const Color(0xFFD9534F)}; // Vermelho
    }

    // 2. Filtra agendamentos no cache local para verificar se o dia possui marcações
    String dataAlvoIso = dataAlvo.toIso8601String().substring(0, 10);
    var agendamentosDoDia = _agendamentosDaSemana.where((agendamento) {
      return agendamento['data_agendamento'] == dataAlvoIso;
    }).toList();

    if (agendamentosDoDia.isNotEmpty) {
      return {'status': 'Ocupado', 'cor': const Color(0xFF428BCA)}; // Azul
    }

    // 3. Se trabalha e não há agendamentos, o dia está livre
    return {'status': 'Disponível', 'cor': const Color(0xFF5CB85C)}; // Verde
  }

  String _formatarIntervaloSemana(DateTime data) {
    int diasDesdeDomingo = data.weekday == 7 ? 0 : data.weekday;
    
    DateTime primeiroDiaSemana = data.subtract(Duration(days: diasDesdeDomingo));
    DateTime ultimoDiaSemana = primeiroDiaSemana.add(const Duration(days: 6));

    String mesTexto = _meses[primeiroDiaSemana.month - 1];
    
    if (primeiroDiaSemana.month != ultimoDiaSemana.month) {
      return "Semana, ${primeiroDiaSemana.day} de ${_meses[primeiroDiaSemana.month - 1].substring(0, 3)} a ${ultimoDiaSemana.day} de ${_meses[ultimoDiaSemana.month - 1].substring(0, 3)}";
    }

    return "Semana, ${primeiroDiaSemana.day} a ${ultimoDiaSemana.day} de $mesTexto";
  }

  void _avancarSemana() {
    setState(() {
      _dataBaseSemana = _dataBaseSemana.add(const Duration(days: 7));
    });
    _buscarDadosSemanais();
  }

  void _retrocederSemana() {
    setState(() {
      _dataBaseSemana = _dataBaseSemana.subtract(const Duration(days: 7));
    });
    _buscarDadosSemanais();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Agenda semanal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 16),

              // 3. SELETOR DINÂMICO DE SEMANA
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
                        onPressed: _retrocederSemana,
                      ),
                      Expanded(
                        child: Text(
                          _formatarIntervaloSemana(_dataBaseSemana),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 24, color: Colors.black),
                        onPressed: _avancarSemana,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. LISTA DOS DIAS DA SEMANA
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _diasNomes.length,
                            itemBuilder: (context, index) {
                              final String nomeDia = _diasNomes[index];
                              final Map<String, dynamic> statusDia = _calcularStatusDoDia(index);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9CC9BC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.black, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        nomeDia,
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.black),
                                      ),
                                      Container(
                                        width: 140,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusDia['cor'],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black, width: 0.8),
                                        ),
                                        child: Text(
                                          statusDia['status'],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. BOTÃO INFERIOR
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Recarrega os dados e invalida o cache ao retornar das configurações
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfigAgendaPage()),
                      );
                      _buscarDadosSemanais();
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