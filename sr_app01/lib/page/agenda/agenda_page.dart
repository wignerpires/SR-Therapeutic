import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sr_app01/page/agenda/agenda_diaria_page.dart';
import 'package:sr_app01/page/agenda/agenda_mensal_page.dart';
import 'package:sr_app01/page/agenda/agenda_semanal_page.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  // Instância do cliente Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável para armazenar o nome do profissional logado dinamicamente
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  // Função assíncrona para buscar o nome do profissional logado
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4), // Fundo verde-menta pastel
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
            ),
          ),
          
          // Conteúdo da Tela
          Column(
            children: [
              // 1. CABEÇALHO PADRÃO COM BOTÃO DE VOLTAR (DINÂMICO)
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
                    // Avatar do Usuário
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 30, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    
                    // Nome do Profissional Dinâmico
                    Expanded(
                      child: Text(
                        _nomeProfissional, // Nome real vindo do banco de dados
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    
                    // Ícone de Voltar (Seta curvada)
                    IconButton(
                      icon: const Icon(Icons.reply, size: 32, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context); // Retorna para a HomePage
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // 2. TÍTULO DA TELA ("Minha agenda")
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Minha agenda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),

              // 3. BOTÕES VERTICAIS (Dia, Semana e Mes)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Column(
                    children: [
                      _buildAgendaButton(
                        title: 'Dia',
                        onTap: () { 
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AgendaDiariaPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildAgendaButton(
                        title: 'Semana',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AgendaSemanalPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildAgendaButton(
                        title: 'Mes', // Mantido sem acento conforme o protótipo
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AgendaMensalPage()),
                          );
                        },
                      ),
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

  // Função auxiliar para estruturar os botões do submenu
  Widget _buildAgendaButton({required String title, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC5993F), // Dourado escuro padrão dos botões
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}