import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/pacientes/agendar_consulta_page.dart';
import 'package:sr_app01/page/pacientes/evolucao_page.dart';
import 'package:sr_app01/page/pacientes/historico_paciente_page.dart';
import 'package:sr_app01/page/pacientes/anamnese_page.dart';

class DetalhePacientePage extends StatefulWidget {
  final String nomePaciente;
  final String idPaciente;

  const DetalhePacientePage({
    super.key,
    required this.idPaciente,
    required this.nomePaciente,
  });

  @override
  State<DetalhePacientePage> createState() => _DetalhePacientePageState();
}

class _DetalhePacientePageState extends State<DetalhePacientePage> {
  // Instância do cliente Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável para armazenar o nome do profissional ativo no cabeçalho
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional(); // Busca o nome do banco de dados assim que a tela abre
  }

  // Função para buscar o nome do profissional logado na tabela 'perfis'
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

  // Widget utilitário interno para criar os botões verticais
  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.65,
        height: 64,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCE9E43), // Tom dourado padrão
            foregroundColor: Colors.black,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.black, width: 1.2),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4), // Verde-menta de fundo
      body: Stack(
        children: [
          // Ondas douradas no fundo inferior com tratamento de erro nativo
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
          
          Column(
            children: [
              // 1. CABEÇALHO PADRÃO DINÂMICO
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
                        _nomeProfissional, // Nome dinâmico injetado aqui
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
                  'Paciente',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 20),

              // 3. CARD DO PACIENTE ATUAL (Exibe o nome passado por parâmetro)
              Container(
                width: MediaQuery.of(context).size.width * 0.60,
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
                        widget.nomePaciente, // Acessado via widget no StatefulWidget
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. BOTÕES DE AÇÃO CENTRALIZADOS
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        text: 'Histórico',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoricoPacientePage(
                                pacienteId: widget.idPaciente,
                                nomePaciente: widget.nomePaciente,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildActionButton(
                        text: 'Anamnese',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnamnesePage(
                                pacienteId: widget.idPaciente,
                                nomePaciente: widget.nomePaciente,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildActionButton(
                        text: 'Evolução',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EvolucaoPage(
                                pacienteId: widget.idPaciente, 
                                nomePaciente: widget.nomePaciente,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildActionButton(
                        text: 'Agendar',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AgendarConsultaPage(
                                idPaciente: widget.idPaciente,
                                nomePaciente: widget.nomePaciente,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40), // Evita sobreposição com as ondas
                    ],
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