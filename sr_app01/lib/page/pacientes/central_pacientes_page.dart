import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/pacientes/pacientes_page.dart';
import 'package:sr_app01/page/pacientes/cadastro_paciente_page.dart';
import 'package:sr_app01/page/pacientes/gerenciar_pacientes_page.dart';

class CentralPacientesPage extends StatefulWidget {
  const CentralPacientesPage({super.key});

  @override
  State<CentralPacientesPage> createState() => _CentralPacientesPageState();
}

class _CentralPacientesPageState extends State<CentralPacientesPage> {
  // Instância do Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável para armazenar o nome carregado
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional(); // Busca o nome assim que a tela abre
  }

  // Função de busca integrada perfeitamente no escopo da tela
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

  // Widget utilitário interno para os botões da central
  Widget _buildCentralButton({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.65,
        height: 68,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCE9E43),
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
              fontSize: 32,
              fontWeight: FontWeight.w400,
              fontFamily: 'sans-serif',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4),
      body: Stack(
        children: [
          // Ondas douradas no fundo inferior com tratamento de erro
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
          
          // Conteúdo da Tela
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
                    
                    // Nome dinâmico injetado aqui
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
                  'Central de pacientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              
              // 3. BOTÕES DE AÇÃO CENTRALIZADOS
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCentralButton(
                        text: 'Cadastrar',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CadastroPacientePage()),   
                          );
                        },
                      ),
                      _buildCentralButton(
                        text: 'Buscar',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PacientesPage()),
                          );
                        },
                      ),
                      _buildCentralButton(
                        text: 'Gerenciar',
                        context: context,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GerenciarPacientesPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 60),
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