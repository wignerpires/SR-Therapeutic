import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgendarConsultaPage extends StatefulWidget {
  final String idPaciente;
  final String nomePaciente;

  const AgendarConsultaPage({
    super.key,
    required this.idPaciente,
    required this.nomePaciente,
  });

  @override
  State<AgendarConsultaPage> createState() => _AgendarConsultaPageState();
}

class _AgendarConsultaPageState extends State<AgendarConsultaPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();

  // Armazenamento das instâncias reais para salvar no Supabase
  DateTime? _dataObjeto;
  TimeOfDay? _horaObjeto;

  // Estados para monitorar as validações com a agenda e nome do profissional
  String _nomeProfissional = 'Carregando...';
  String _statusDia = '';     // 'Disponível', 'Ocupado', 'Indisponível' ou ''
  String _statusHorario = ''; // 'Disponível', 'Ocupado', 'Verificando...', 'Inválido' ou ''
  bool _salvando = false;

  // Variáveis para o Dropdown de Serviços
  List<Map<String, dynamic>> _listaServicos = [];
  int? _idServicoSelecionado;
  String? _nomeServicoSelecionado;
  bool _carregandoServicos = true;

  // Cache das configurações do profissional
  Map<String, dynamic>? _configAgenda;

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  @override
  void dispose() {
    _dataController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _inicializarDados() async {
    await _buscarNomeProfissional();
    await _buscarConfiguracoesAgenda();
    await _buscarServicos();
  }

  // FUNÇÃO DO NOME: Busca o nome dinâmico do profissional logado
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
          if (mounted) {
            setState(() {
              _nomeProfissional = dadosPerfil['nome'];
            });
          }
        } else {
          if (mounted) setState(() => _nomeProfissional = 'Profissional');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _nomeProfissional = 'Profissional');
    }
  }

  // Carrega as regras globais de dias de atendimento (dom, seg, ter...) do profissional
  Future<void> _buscarConfiguracoesAgenda() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final config = await _supabase
          .from('config_agenda')
          .select()
          .eq('id_usuario', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _configAgenda = config;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar configurações: $e');
    }
  }

  // BUSCA OS SERVIÇOS: Traz os serviços ativos cadastrados pelo profissional logado trazendo também o PREÇO
  Future<void> _buscarServicos() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final dados = await _supabase
          .from('servicos')
          .select('id, nome, preco') // Traz id, nome e preco
          .eq('id_usuario', user.id)
          .eq('ativo', true)         // Filtra apenas serviços ativos
          .order('nome');

      if (mounted) {
        setState(() {
          _listaServicos = List<Map<String, dynamic>>.from(dados);
          _carregandoServicos = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar serviços: $e');
      if (mounted) {
        setState(() => _carregandoServicos = false);
      }
    }
  }

  // Abre o calendário e checa o status real do dia no banco de dados
  Future<void> _selecionarData(BuildContext context) async {
    final user = _supabase.auth.currentUser;
    if (user == null || _configAgenda == null) return;

    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFCE9E43),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (escolhida != null) {
      setState(() {
        _statusHorario = '';
        _horarioController.clear();
        _horaObjeto = null;
        
        final String dataFormatada = "${escolhida.day.toString().padLeft(2, '0')}/${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}";
        _dataController.text = dataFormatada;
        _dataObjeto = escolhida;
      });

      // 1. Validar se atende nesse dia da semana com base na config_agenda
      List<String> siglasDias = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'];
      String siglaDia = siglasDias[escolhida.weekday % 7];
      bool atendeNesseDia = _configAgenda![siglaDia] ?? false;

      if (!atendeNesseDia) {
        setState(() {
          _statusDia = 'Indisponível';
        });
        return;
      }

      // 2. Buscar agendamentos existentes no dia para checar se está ocupado/livre
      String dataIso = escolhida.toIso8601String().substring(0, 10);
      final agendamentosNoDia = await _supabase
          .from('agendamentos')
          .select()
          .eq('id_usuario', user.id)
          .eq('data_agendamento', dataIso);

      if (mounted) {
        setState(() {
          if (agendamentosNoDia.isNotEmpty) {
            _statusDia = 'Ocupado'; 
          } else {
            _statusDia = 'Disponível';
          }
        });
      }
    }
  }

  // Valida se o horário está dentro do expediente e se não há conflitos
  Future<void> _validarEDispararConsultaHorario(String valorDigitado) async {
    if (_dataObjeto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione primeiro uma Data.')),
      );
      _horarioController.clear();
      return;
    }

    if (valorDigitado.length < 5) {
      setState(() => _statusHorario = '');
      return;
    }

    TimeOfDay? validada;
    try {
      final partes = valorDigitado.split(':');
      final hora = int.parse(partes[0]);
      final minuto = int.parse(partes[1]);

      if (hora >= 0 && hora < 24 && minuto >= 0 && minuto < 60) {
        validada = TimeOfDay(hour: hora, minute: minuto);
      }
    } catch (_) {}

    if (validada == null) {
      setState(() => _statusHorario = 'Inválido');
      return;
    }

    if (_configAgenda == null) {
      setState(() => _statusHorario = 'Erro Config');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _horaObjeto = validada;
      _statusHorario = 'Verificando...';
    });

    // VALIDAÇÃO DE EXPEDIENTE
    final stringInicio = _configAgenda!['horario_inicio'] as String?;
    final stringFim = _configAgenda!['horario_fim'] as String?;
    final stringPausaInicio = _configAgenda!['pausa_inicio'] as String?;
    final stringPausaFim = _configAgenda!['pausa_fim'] as String?;

    if (stringInicio != null && stringFim != null) {
      if (valorDigitado.compareTo(stringInicio) < 0 || valorDigitado.compareTo(stringFim) >= 0) {
        setState(() => _statusHorario = 'Indisponível');
        return;
      }
      
      if (stringPausaInicio != null && stringPausaFim != null && 
          stringPausaInicio.isNotEmpty && stringPausaFim.isNotEmpty) {
        if (valorDigitado.compareTo(stringPausaInicio) >= 0 && valorDigitado.compareTo(stringPausaFim) < 0) {
          setState(() => _statusHorario = 'Indisponível');
          return;
        }
      }
    }

    // CONFLITO DE HORÁRIO
    String dataIso = _dataObjeto!.toIso8601String().substring(0, 10);

    try {
      final conflito = await _supabase
          .from('agendamentos')
          .select()
          .eq('id_usuario', user.id)
          .eq('data_agendamento', dataIso)
          .eq('horario_inicio', valorDigitado)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        if (conflito != null) {
          _statusHorario = 'Ocupado';
        } else {
          _statusHorario = 'Disponível';
        }
      });
    } catch (e) {
      debugPrint('Erro ao verificar horário no banco: $e');
      if (mounted) {
        setState(() => _statusHorario = 'Erro');
      }
    }
  }

  // Salva a consulta no banco e vincula o lançamento financeiro automático
  Future<void> _confirmarAgendamento() async {
    if (_dataObjeto == null || _horaObjeto == null || _idServicoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos antes de confirmar.')),
      );
      return;
    }

    if (_statusHorario != 'Disponível' || _statusDia != 'Disponível') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O horário selecionado não está disponível.')),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Busca o preço do serviço para snapshot
      final servicoSelecionado = _listaServicos.firstWhere(
        (s) => s['id'] == _idServicoSelecionado,
      );
      final double precoServico = double.parse(servicoSelecionado['preco'].toString());

      String dataIso = _dataObjeto!.toIso8601String().substring(0, 10);
      String horaFormatada = "${_horaObjeto!.hour.toString().padLeft(2, '0')}:${_horaObjeto!.minute.toString().padLeft(2, '0')}";

      // 2. Inserção do Agendamento e extração do ID gerado
      final agendamentoResp = await _supabase.from('agendamentos').insert({
        'id_usuario': user.id,
        'id_paciente': widget.idPaciente,
        'data_agendamento': dataIso,
        'horario_inicio': horaFormatada,
        'id_servico': _idServicoSelecionado,
        'observacao': _nomeServicoSelecionado,
      }).select().single();

      final agendamentoId = agendamentoResp['id'];

      // 3. Inserção Automática na Tabela 'lancamentos_financeiros'
      await _supabase.from('lancamentos_financeiros').insert({
        'id_usuario': user.id,
        'agendamento_id': agendamentoId,
        'paciente_id': widget.idPaciente,
        'tipo': 'ENTRADA',
        'descricao': 'Pix Recebido',
        'subdescricao': 'Des: ${widget.nomePaciente} ${dataIso.substring(8, 10)}/${dataIso.substring(5, 7)}',
        'documento_ref': '123${agendamentoId.toString().padLeft(4, '0')}',
        'valor': precoServico,
        'forma_pagamento': 'PIX',
        'status': 'PENDENTE',
        'data_competencia': dataIso,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consulta agendada e anexada ao relatório financeiro!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar consulta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disponível':
        return const Color(0xFF4CAF50);
      case 'Ocupado':
        return const Color(0xFF2196F3);
      case 'Indisponível':
      case 'Inválido':
      case 'Erro':
        return const Color(0xFFEF5350);
      case 'Verificando...':
        return Colors.orange;
      default:
        return Colors.transparent;
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool readOnly,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    int? maxLength,
    String? statusInfo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    readOnly: readOnly,
                    onTap: onTap,
                    onChanged: onChanged,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      fillColor: Colors.white,
                      filled: true,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black, width: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
              if (statusInfo != null && statusInfo.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusInfo),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 0.8),
                  ),
                  child: Text(
                    statusInfo,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<int>(
              value: _idServicoSelecionado,
              hint: Text(
                _carregandoServicos ? 'Carregando serviços...' : hintText,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black, width: 0.8),
                ),
              ),
              items: _listaServicos.map((servico) {
                return DropdownMenuItem<int>(
                  value: servico['id'] as int,
                  child: Text(
                    '${servico['nome']} - R\$ ${servico['preco']}',
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                );
              }).toList(),
              onChanged: _carregandoServicos
                  ? null
                  : (int? novoId) {
                      if (novoId != null) {
                        final servicoEscolhido = _listaServicos.firstWhere((s) => s['id'] == novoId);
                        setState(() {
                          _idServicoSelecionado = novoId;
                          _nomeServicoSelecionado = servicoEscolhido['nome'];
                        });
                      }
                    },
            ),
          ),
        ],
      ),
    );
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
          
          SingleChildScrollView(
            child: Column(
              children: [
                // 1. CABEÇALHO DINÂMICO
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
                    'Agendar Consulta',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                  ),
                ),
                
                const SizedBox(height: 20),

                // 3. CARD DO PACIENTE ATUAL
                Container(
                  width: MediaQuery.of(context).size.width * 0.65,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.face, color: Colors.amber, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.nomePaciente,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // 4. CAMPOS DE ENTRADA
                _buildInputField(
                  label: 'Data',
                  controller: _dataController,
                  hintText: 'Selecione a data da consulta',
                  readOnly: true,
                  onTap: () => _selecionarData(context),
                  statusInfo: _statusDia,
                ),

                _buildInputField(
                  label: 'Horário',
                  controller: _horarioController,
                  hintText: 'Ex: 14:30',
                  readOnly: false,
                  keyboardType: TextInputType.datetime,
                  maxLength: 5,
                  onChanged: _validarEDispararConsultaHorario,
                  statusInfo: _statusHorario,
                ),

                _buildDropdownField(
                  label: 'Procedimento / Serviço',
                  hintText: 'Selecione o serviço desejado',
                ),

                const SizedBox(height: 30),

                // 5. BOTÃO DE CONFIRMAÇÃO
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.50,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_statusDia == 'Indisponível' || _statusHorario == 'Ocupado' || _statusHorario == 'Inválido' || _statusHorario == 'Verificando...' || _idServicoSelecionado == null || _salvando)
                        ? null 
                        : _confirmarAgendamento,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE9E43),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black, width: 1.2),
                      ),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Text(
                            'Confirmar',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                          ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}