import 'package:flutter/material.dart';
import 'package:sr_app01/page/contabil_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importação do Supabase adicionada
import 'package:sr_app01/page/financeiro/financeiro_page.dart';
import 'package:sr_app01/page/agenda/agenda_page.dart';
import 'package:sr_app01/page/pacientes/central_pacientes_page.dart';
import 'package:sr_app01/page/configuracoes_page.dart';
import 'package:sr_app01/page/lista_agendamentos_page.dart';
import 'package:sr_app01/page/financeiro/servicos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Instância do Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável que guardará o nome do usuário ativo
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional(); // Dispara a busca ao iniciar a tela
  }

  // A sua função de busca integrada perfeitamente no escopo do State
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
      // Fundo Verde Claro (Tom pastel/menta da imagem)
      backgroundColor: const Color(0xFF9FD3C4), 
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
          
          // Conteúdo Principal da Tela
          Column(
            children: [
              // 1. CABEÇALHO PERSONALIZADO (Topo Dourado Claro)
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: const Color(0xFFF0DCA7), // Cor de fundo do cabeçalho
                child: Row(
                  children: [
                    // Avatar / Foto do Usuário
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 30, color: Colors.grey), 
                    ),
                    const SizedBox(width: 12),
                    
                    // Nome do Profissional dinâmico vindo do Supabase
                    Expanded(
                      child: Text(
                        _nomeProfissional, // Substituído o texto fixo pela variável
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    
                    // Ícone de Configurações
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 32, color: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Espaçador do cabeçalho para a Logo
              const SizedBox(height: 24),

              // 2. LOGOTIPO CENTRALIZADO (Versão Verde Escuro)
              const Text(
                'S.R.',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff123D24), // Verde escuro idêntico ao fundo das outras telas
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Text(
                'Therapeutic',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  color: Color(0xff123D24),
                  letterSpacing: 1.5,
                ),
              ),
              
              const SizedBox(height: 32),

              // 3. MENU EM GRID (Os 4 Grandes Botões)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GridView.count(
                    crossAxisCount: 2, // 2 Colunas
                    crossAxisSpacing: 16, // Espaçamento horizontal entre os botões
                    mainAxisSpacing: 16, // Espaçamento vertical entre os botões
                    children: [
                      _buildMenuButton(
                        context: context,
                        title: 'Calendário',
                        icon: Icons.calendar_month_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AgendaPage()),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: 'Pacientes',
                        icon: Icons.groups_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CentralPacientesPage()),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: 'Financeiro',
                        icon: Icons.monetization_on_outlined,
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FinanceiroPage()), 
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: 'Agendamentos',
                        icon: Icons.assignment_outlined,
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ListaAgendamentosPage()),
                          ); 
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: 'Serviços',
                        icon: Icons.assignment_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ServicosPage()),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        title: 'Contábil',
                        icon: Icons.assignment_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ContabilPage()),
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

  // Função auxiliar para construir cada quadrado do menu de forma limpa
  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC5993F), // Dourado escuro dos botões
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1), // Borda fina preta
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: Colors.black, // Ícones pretos conforme a imagem
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}