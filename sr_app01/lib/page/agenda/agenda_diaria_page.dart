import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/agenda/config_agenda_page.dart';

class AgendaDiariaPage extends StatefulWidget {
  const AgendaDiariaPage({super.key});

  @override
  State<AgendaDiariaPage> createState() => _AgendaDiariaPageState();
}

class _AgendaDiariaPageState extends State<AgendaDiariaPage> {
  DateTime _dataSelecionada = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String _nomeProfissional = 'Carregando...';
  bool _carregandoDados = true;

  // Estruturas para guardar o que vem do Supabase
  Map<String, dynamic>? _configAgenda;
  List<dynamic> _agendamentosDoDia = [];

  final List<String> _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
  ];

  // Lista fixa de horários que o app renderiza no Grid (das 06:00 às 23:00)
  final List<String> _gradeHorarios = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
    '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
  ];

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _buscarNomeProfissional();
    await _buscarDadosAgenda();
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

  // Faz a busca síncrona das configurações e dos agendamentos da data selecionada
  Future<void> _buscarDadosAgenda() async {
    setState(() => _carregandoDados = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Busca configurações de atendimento
      final config = await _supabase
          .from('config_agenda')
          .select()
          .eq('id_usuario', user.id)
          .maybeSingle();

      // 2. Formata a data atual para YYYY-MM-DD para filtrar no banco
      String dataFormatadaIso = _dataSelecionada.toIso8601String().substring(0, 10);

      // 3. Busca agendamentos reais do dia
      final agendamentos = await _supabase
          .from('agendamentos')
          .select()
          .eq('id_usuario', user.id)
          .eq('data_agendamento', dataFormatadaIso);

      setState(() {
        _configAgenda = config;
        _agendamentosDoDia = agendamentos;
      });
    } catch (e) {
      debugPrint('Erro ao buscar dados da agenda: $e');
    } finally {
      setState(() => _carregandoDados = false);
    }
  }

  // Define a cor de cada bloco baseado nas regras do negócio
  Color _definirCorHorario(String hora) {
    if (_configAgenda == null) return Colors.grey; // Sem config salva = Indisponível

    // 1. Mapeamento e checagem do dia da semana
    List<String> diasDaSemana = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'];
    String diaSemanaAtual = diasDaSemana[_dataSelecionada.weekday % 7];
    bool atendeHoje = _configAgenda![diaSemanaAtual] ?? false;

    if (!atendeHoje) return Colors.grey; // Dia desmarcado = Cinza

    // 2. Checagem de horário de expediente e intervalo de almoço
    String inicioExpediente = _configAgenda!['horario_inicio'] ?? '08:00';
    String fimExpediente = _configAgenda!['horario_fim'] ?? '18:00';
    String inicioAlmoco = _configAgenda!['pausa_inicio'] ?? '12:00';
    String fimAlmoco = _configAgenda!['pausa_fim'] ?? '13:30';

    // Se o horário avaliado estiver fora do expediente comercial ou dentro da pausa do almoço
    if (hora.compareTo(inicioExpediente) < 0 || 
        hora.compareTo(fimExpediente) >= 0 ||
        (hora.compareTo(inicioAlmoco) >= 0 && hora.compareTo(fimAlmoco) < 0)) {
      return Colors.grey; // Indisponível = Cinza
    }

    // 3. Checagem se existe agendamento marcado (Ocupado)
    // Compara os primeiros 5 caracteres (ex: "08:00") para evitar inconsistências de formatação
    bool estaOcupado = _agendamentosDoDia.any((agendamento) {
      String horaAgendada = agendamento['horario_inicio'] ?? '';
      return horaAgendada.startsWith(hora);
    });

    if (estaOcupado) return Colors.blue; // Ocupado = Azul

    // 4. Se passou em todos os filtros anteriores, o horário está disponível
    return Colors.green; // Disponível = Verde
  }

  String _formatarData(DateTime data) {
    DateTime agora = DateTime.now();
    String diaEMes = "${data.day} de ${_meses[data.month - 1]}";
    
    if (data.year == agora.year && data.month == agora.month && data.day == agora.day) {
      return "Hoje, $diaEMes";
    }
    return diaEMes;
  }

  void _avancarDia() {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(const Duration(days: 1));
    });
    _buscarDadosAgenda(); // Recarrega os dados do novo dia
  }

  void _retrocederDia() {
    setState(() {
      _dataSelecionada = _dataSelecionada.subtract(const Duration(days: 1));
    });
    _buscarDadosAgenda(); // Recarrega os dados do novo dia
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
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
                  'Agenda diária',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // 3. BARRA SELETORA DE DATA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D9B84),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 24, color: Colors.black),
                        onPressed: _retrocederDia,
                      ),
                      Expanded(
                        child: Text(
                          _formatarData(_dataSelecionada),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 24, color: Colors.black),
                        onPressed: _avancarDia,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. GRID DE HORÁRIOS DENTRO DO BLOCO BRANCO
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
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
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _gradeHorarios.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.8,
                            ),
                            itemBuilder: (context, index) {
                              final horaStr = _gradeHorarios[index];
                              // Converte do formato "08:00" para exibição limpa "8h" ou "14h"
                              final int horaInt = int.parse(horaStr.split(':')[0]);
                              final labelExibicao = '${horaInt}h';
                              
                              // Obtém a cor reativa calculada pelas regras do banco
                              final Color corStatus = _definirCorHorario(horaStr);

                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9CC9BC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text(
                                      labelExibicao,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: corStatus,
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
                      // O uso do await aqui garante que se o usuário alterar as configurações de dias ou horas
                      // na tela de configurações, ao retornar à tela diária, ela se atualize instantaneamente.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfigAgendaPage()),
                      );
                      _buscarDadosAgenda();
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