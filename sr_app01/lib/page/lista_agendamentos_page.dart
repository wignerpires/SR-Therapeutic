import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaAgendamentosPage extends StatefulWidget {
  const ListaAgendamentosPage({super.key});

  @override
  State<ListaAgendamentosPage> createState() => _ListaAgendamentosPageState();
}

class _ListaAgendamentosPageState extends State<ListaAgendamentosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _nomeProfissional = 'Carregando...';
  bool _processandoStatus = false;

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  // 1. FUNÇÃO DO NOME: Busca o nome do profissional logado (tabela perfis) para o cabeçalho
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
          setState(() {
            _nomeProfissional = 'Profissional';
          });
        }
      }
    } catch (e) {
      setState(() {
        _nomeProfissional = 'Profissional';
      });
    }
  }

  // 2. PARTE DE LISTAR: Traz as consultas fazendo JOIN para buscar o nome do paciente
  Future<List<Map<String, dynamic>>> _buscarAgendamentosDoDia() async {
    final response = await _supabase
        .from('agendamentos')
        .select('id, horario_inicio, observacao, pacientes(nome)')
        .order('horario_inicio', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // 3. FUNÇÃO CONFIRMAR PRESENÇA / NÃO COMPARECEU + ATUALIZAR STATUS FINANCEIRO
  Future<void> _atualizarStatusPresenca(dynamic agendamentoId, String novoStatus) async {
    setState(() => _processandoStatus = true);
    try {
      // A. Atualiza o agendamento
      await _supabase
          .from('agendamentos')
          .update({
            'observacao': novoStatus,
            'id_paciente': null, // Libera a vaga na agenda
          })
          .eq('id', agendamentoId);

      // B. Atualiza o lançamento financeiro correspondente
      final String statusFinanceiro = (novoStatus == 'Compareceu') ? 'PAGO' : 'CANCELADO';

      await _supabase
          .from('lancamentos_financeiros')
          .update({'status': statusFinanceiro})
          .eq('agendamento_id', agendamentoId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              novoStatus == 'Compareceu'
                  ? 'Presença confirmada! Lançamento financeiro registrado como PAGO.'
                  : 'Falta registrada! Lançamento financeiro CANCELADO.',
            ),
            backgroundColor: novoStatus == 'Compareceu' ? Colors.green : Colors.orange,
          ),
        );
      }

      // Recarrega a listagem da tela atualizada
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar presença/financeiro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoStatus = false);
    }
  }

  // Widget utilitário para os botões de ação (Presença e Falta)
  Widget _buildStatusButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              elevation: 1,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 0.8),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4), // Fundo verde-menta padrão do app
      body: Stack(
        children: [
          // Ondas douradas no fundo inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/ondas_douradas.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          
          // Conteúdo Principal
          Column(
            children: [
              // 1. CABEÇALHO COM FUNÇÃO DO NOME DO PROFISSIONAL
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: const Color(0xFFF0DCA7), // Dourado claro
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

              // 2. TÍTULO DA SEÇÃO
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Agendamentos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 15),

              if (_processandoStatus)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE9E43))),
                ),

              // 3. EXIBIÇÃO DA LISTA INTEGRADA AO BANCO DE DADOS
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buscarAgendamentosDoDia(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE9E43)),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Erro ao carregar consultas do dia.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      );
                    }

                    final agendamentosBanco = snapshot.data ?? [];

                    if (agendamentosBanco.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma consulta agendada para hoje.',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                      itemCount: agendamentosBanco.length,
                      itemBuilder: (context, index) {
                        final item = agendamentosBanco[index];
                        final idAgendamento = item['id'];
                        final horaStr = item['horario_inicio'] ?? '--:--';
                        final statusAtual = item['observacao'] ?? 'Pendente';
                        
                        // Captura o nome de dentro do mapa interno do relacionamento 'pacientes'
                        final mapaPaciente = item['pacientes'] as Map<String, dynamic>?;
                        
                        final nomePaciente = mapaPaciente != null 
                            ? mapaPaciente['nome'] 
                            : (statusAtual != 'Pendente' ? 'Horário Liberado' : 'Paciente não encontrado');

                        final bool foiRespondido = statusAtual == 'Compareceu' || statusAtual == 'Não Compareceu';

                        return Opacity(
                          opacity: foiRespondido ? 0.6 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade400, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Badge do Horário
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE4C47A),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.black, width: 0.8),
                                        ),
                                        child: Text(
                                          horaStr,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      
                                      // Nome do Paciente do Banco de Dados
                                      Expanded(
                                        child: Text(
                                          nomePaciente,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      
                                      // Ícone indicador visual do status
                                      if (statusAtual == 'Compareceu')
                                        const Icon(Icons.check_circle, color: Colors.green, size: 26)
                                      else if (statusAtual == 'Não Compareceu')
                                        const Icon(Icons.cancel, color: Colors.red, size: 26),
                                    ],
                                  ),
                                  
                                  // Se ainda não foi marcada a presença, exibe os botões de ação
                                  if (!foiRespondido) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Colors.grey),
                                    const SizedBox(height: 12),
                                    
                                    Row(
                                      children: [
                                        _buildStatusButton(
                                          label: 'Confirmar Presença',
                                          color: const Color(0xFF9CC9BC), // Verde suave do app
                                          onTap: () => _atualizarStatusPresenca(idAgendamento, 'Compareceu'),
                                        ),
                                        _buildStatusButton(
                                          label: 'Não Compareceu',
                                          color: const Color(0xFFE57373), // Vermelho de alerta
                                          onTap: () => _atualizarStatusPresenca(idAgendamento, 'Não Compareceu'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
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
        ],
      ),
    );
  }
}