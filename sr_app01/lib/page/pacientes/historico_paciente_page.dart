import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HistoricoPacientePage extends StatefulWidget {
  final String pacienteId;
  final String nomePaciente;

  const HistoricoPacientePage({
    super.key,
    required this.pacienteId,
    required this.nomePaciente,
  });

  @override
  State<HistoricoPacientePage> createState() => _HistoricoPacientePageState();
}

class _HistoricoPacientePageState extends State<HistoricoPacientePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _carregando = true;
  List<Map<String, dynamic>> _historicosUnificados = [];
  String _nomeProfissional = 'Profissional';

  @override
  void initState() {
    super.initState();
    _buscarDadosCronologicos();
  }

  Future<void> _buscarDadosCronologicos() async {
    setState(() => _carregando = true);
    try {
      // 1. Busca o nome do profissional logado para o cabeçalho
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final perfil = await _supabase.from('perfis').select('nome').eq('id', user.id).maybeSingle();
        if (perfil != null && perfil['nome'] != null) {
          _nomeProfissional = perfil['nome'];
        }
      }

      // 2. Dispara as consultas em paralelo para máxima performance
      final resultados = await Future.wait([
        _supabase.from('historico_paciente').select('*').eq('paciente_id', widget.pacienteId),
        _supabase.from('sessoes_evolucao').select('*').eq('paciente_id', widget.pacienteId),
        _supabase.from('agendamentos').select('*').eq('id_paciente', widget.pacienteId), // Se sua tabela tiver outro nome, ajuste aqui
      ]);

      final List<dynamic> dadosAnamnese = resultados[0];
      final List<dynamic> dadosEvolucao = resultados[1];
      final List<dynamic> dadosAtendimentos = resultados[2];

      List<Map<String, dynamic>> listaTemporaria = [];

      // Mapeia registros da Anamnese
      for (var item in dadosAnamnese) {
        DateTime dataCriacao = DateTime.parse(item['created_at']);
        listaTemporaria.add({
          'timestamp': dataCriacao,
          'data': DateFormat('dd/MM/yyyy').format(dataCriacao),
          'horario': DateFormat('HH:mm').format(dataCriacao),
          'procedimento': 'Ficha de Anamnese',
          'detalhes': 'Ficha inicial de anamnese clínica cadastrada no sistema. Contém o mapeamento de queixas primárias, hábitos e histórico patológico.',
          'cor_icone': Colors.blueAccent,
          'icone': Icons.assignment_turned_in,
        });
      }

      // Mapeia registros da Evolução Clínica dedicada
      for (var item in dadosEvolucao) {
        DateTime dataCriacao = item['created_at'] != null ? DateTime.parse(item['created_at']) : DateTime.now();
        int numSessao = item['numero_sessao'] ?? 0;
        String dataDigitada = item['data_sessao'] ?? '';
        
        String detalhesStr = 'Sessão número: $numSessao\n';
        if (item['dor_nivel'] != null) detalhesStr += 'Nível de dor relatado: ${item['dor_nivel']}/10\n';
        if (item['evolucao_detalhes'] != null) detalhesStr += 'Evolução: ${item['evolucao_detalhes']}\n';
        if (item['pontos_tecnicas'] != null) detalhesStr += 'Pontos/Técnicas aplicadas: ${item['pontos_tecnicas']}\n';
        if (item['situacao_pos_tratamento'] != null) detalhesStr += 'Situação pós-tratamento: ${item['situacao_pos_tratamento']}';

        listaTemporaria.add({
          'timestamp': dataCriacao,
          'data': dataDigitada.isNotEmpty ? dataDigitada : DateFormat('dd/MM').format(dataCriacao),
          'horario': DateFormat('HH:mm').format(dataCriacao),
          'procedimento': numSessao == 0 ? 'Evolução Inicial' : 'Evolução - Sessão $numSessao',
          'detalhes': detalhesStr,
          'cor_icone': const Color(0xFFCE9E43),
          'icone': Icons.trending_up,
        });
      }

      // Mapeia registros genéricos de Atendimentos realizados
      for (var item in dadosAtendimentos) {
        DateTime dataAtendimento = item['data_hora'] != null ? DateTime.parse(item['data_hora']) : DateTime.now();
        listaTemporaria.add({
          'timestamp': dataAtendimento,
          'data': DateFormat('dd/MM/yyyy').format(dataAtendimento),
          'horario': DateFormat('HH:mm').format(dataAtendimento),
          'procedimento': item['servico'] ?? item['procedimento'] ?? 'Atendimento Geral',
          'detalhes': item['observacoes'] ?? item['detalhes'] ?? 'Nenhuma observação extra registrada para este atendimento.',
          'cor_icone': Colors.purple,
          'icone': Icons.medical_services_outlined,
        });
      }

      // 3. Ordena tudo por data de forma Decrescente (Mais recente primeiro)
      listaTemporaria.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _historicosUnificados = listaTemporaria;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar histórico: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarDetalhesAtendimento(BuildContext context, Map<String, dynamic> historico) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF0DCA7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 1.2),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                historico['data'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black),
              ),
              Text(
                historico['horario'],
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
            ],
          ),
          content: MiniFormScroll(historico: historico),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        );
      },
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
              errorBuilder: (context, error, stackTrace) => const SizedBox(), // Evita quebra caso não ache a imagem
            ),
          ),
          
          Column(
            children: [
              // 1. CABEÇALHO DINÂMICO DO SISTEMA
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

              // 2. TÍTULO DA SEÇÃO
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Histórico Clínico',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 15),

              // 3. IDENTIFICAÇÃO DO PACIENTE ATUAL
              Container(
                width: MediaQuery.of(context).size.width * 0.70,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.face, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.nomePaciente,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // 4. CORPO PRINCIPAL COM REFRESH INDICATOR E LISTA REAL
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator(color: Colors.black))
                    : _historicosUnificados.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum evento clínico registrado ainda.',
                              style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
                            ),
                          )
                        : RefreshIndicator(
                            color: Colors.black,
                            onRefresh: _buscarDadosCronologicos,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                              itemCount: _historicosUnificados.length,
                              itemBuilder: (context, index) {
                                final historico = _historicosUnificados[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: GestureDetector(
                                    onTap: () => _mostrarDetalhesAtendimento(context, historico),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade400, width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Bloco da Esquerda: Data customizada
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            width: 60,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9CC9BC),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.black, width: 0.8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  historico['data'].contains('/') 
                                                      ? historico['data'].split('/')[0]
                                                      : historico['data'],
                                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                ),
                                                if (historico['data'].contains('/'))
                                                  Text(
                                                    '/${historico['data'].split('/')[1]}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          
                                          // Bloco Central: Tipo do procedimento e ícone marcador
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      historico['horario'],
                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Icon(historico['icone'], size: 16, color: historico['cor_icone']),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  historico['procedimento'],
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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

// Widget auxiliar para rolagem limpa do modal interno de detalhes
class MiniFormScroll extends StatelessWidget {
  final Map<String, dynamic> historico;
  const MiniFormScroll({super.key, required this.historico});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Procedimento: ${historico['procedimento']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.black38),
          const SizedBox(height: 12),
          const Text(
            'Registro / Observações Clínicas:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            historico['detalhes'],
            style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }
}