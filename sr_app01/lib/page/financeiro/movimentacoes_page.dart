import 'package:flutter/material.dart';
import 'package:sr_app01/page/financeiro/movimentacao_desconto_page.dart';
import 'package:sr_app01/page/financeiro/movimentacao_entradas_page.dart';
import 'package:sr_app01/page/financeiro/movimentacao_reembolsos_page.dart';
import 'package:sr_app01/page/financeiro/movimentacao_saidas_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovimentacoesPage extends StatefulWidget {
  const MovimentacoesPage({super.key});

  @override
  State<MovimentacoesPage> createState() => _MovimentacoesPageState();
}

class _MovimentacoesPageState extends State<MovimentacoesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  // Busca o nome do profissional logado
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

  // Widget utilitário para os botões do menu
  Widget _buildMenuButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE4C47A), // Dourado dos botões
            foregroundColor: Colors.black,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black54, width: 1),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4), // Fundo verde-menta
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
              // 1. Cabeçalho Dourado Superior
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: const Color(0xFFF0DCA7), // Dourado claro do topo
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 28, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nomeProfissional,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.reply, size: 30, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Banner de Título ("Movimentações")
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black26, width: 1),
                ),
                child: const Text(
                  'Movimentações',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 3. Botões das Opções de Movimentação
              _buildMenuButton(
                title: 'Entrada',
                onTap: () {
                  // TODO: NAVEGAR PARA CADASTRO DE ENTRADA
                  Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MovimentacaoEntradasPage()),
                          );
                },
              ),
              _buildMenuButton(
                title: 'Saida',
                onTap: () {
                  // TODO: NAVEGAR PARA CADASTRO DE SAÍDA
                  Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MovimentacaoSaidasPage()),
                          );
                },
              ),
              _buildMenuButton(
                title: 'Desconto',
                onTap: () {
                  // TODO: NAVEGAR PARA CADASTRO DE DESCONTO
                  Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MovimentacaoDescontosPage()),
                          );
                },
              ),
              _buildMenuButton(
                title: 'Reembolso',
                onTap: () {
                  // TODO: NAVEGAR PARA CADASTRO DE REEMBOLSO
                  Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MovimentacaoReembolsosPage()),
                          );
                },
              ),

              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }
}