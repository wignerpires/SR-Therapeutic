import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  // Instância do SupabaseClient
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Variável que guardará o nome dinâmico (inicializada como carregando)
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  // Sua função de busca integrada ao fluxo da tela
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
            _nomeProfissional = dadosPerfil['nome'].toString();
          });
        } else {
          setState(() {
            _nomeProfissional = 'Profissional';
          });
        }
      } else {
        setState(() {
          _nomeProfissional = 'Desconectado';
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar profissional: $e');
      setState(() {
        _nomeProfissional = 'Profissional';
      });
    }
  }

  // Widget utilitário para manter os botões idênticos ao padrão do seu app
  Widget _buildConfigButton({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.65, // Largura padrão dos submenus
        height: 68,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCE9E43), // Dourado escuro dos botões
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
              fontSize: 28, // Fonte grande e legível conforme o protótipo
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
      backgroundColor: const Color(0xFF9FD3C4), // Fundo verde-menta padrão
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
                        _nomeProfissional, // Substituído o nome estático pela variável dinâmica
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
                  'Configurações',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              
              // 3. BOTÕES DE CONFIGURAÇÃO CENTRALIZADOS
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildConfigButton(
                        text: 'Meus dados',
                        context: context,
                        onTap: () {
                          debugPrint('Navegar para Meus Dados');
                        },
                      ),
                      _buildConfigButton(
                        text: 'Segurança',
                        context: context,
                        onTap: () {
                          debugPrint('Navegar para Segurança');
                        },
                      ),
                      _buildConfigButton(
                        text: 'Termos de Uso',
                        context: context,
                        onTap: () {
                          debugPrint('Navegar para Termos de Uso');
                        },
                      ),
                      const SizedBox(height: 60), // Espaço para compensar a curvatura das ondas
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