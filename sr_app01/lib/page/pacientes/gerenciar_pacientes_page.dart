import 'package:flutter/material.dart';
import 'package:sr_app01/page/pacientes/editar_paciente_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GerenciarPacientesPage extends StatefulWidget {
  const GerenciarPacientesPage({super.key});

  @override
  State<GerenciarPacientesPage> createState() => _GerenciarPacientesPageState();
}

class _GerenciarPacientesPageState extends State<GerenciarPacientesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _nomeProfissional = 'Carregando...';
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  // 1. Busca o nome do profissional (tabela perfis) para o cabeçalho
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

  // 2. Retorna a lista real do banco baseado no seu ERD (id, nome, sexo)
  Future<List<Map<String, dynamic>>> _buscarPacientes() async {
    final response = await _supabase
        .from('pacientes')
        .select('id, nome, sexo')
        .order('nome', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // 3. Função para deletar o paciente do banco de dados
  Future<void> _excluirPaciente(String id) async {
    setState(() => _atualizando = true);
    try {
      await _supabase.from('pacientes').delete().eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente excluído com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      // Atualiza a tela após a exclusão
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir paciente: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _atualizando = false);
    }
  }

  // Modal de confirmação antes de deletar de vez
  void _confirmarExclusao(BuildContext context, String id, String nome) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Deseja realmente excluir o paciente $nome? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _excluirPaciente(id);
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Botão utilitário customizado para as ações
  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: 38,
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
                fontSize: 14,
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
              // 1. CABEÇALHO DINÂMICO
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
                  'Gerenciar pacientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 20),

              if (_atualizando)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE9E43))),
                ),

              // 3. LISTA DE PACIENTES INTEGRADA AO SUPABASE
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buscarPacientes(),
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
                          'Erro ao carregar pacientes.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      );
                    }

                    final listaPacientes = snapshot.data ?? [];

                    if (listaPacientes.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum paciente cadastrado.',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                      itemCount: listaPacientes.length,
                      itemBuilder: (context, index) {
                        final paciente = listaPacientes[index];
                        final idStr = paciente['id'].toString();
                        final nomeStr = paciente['nome'] ?? 'Sem nome';
                        
                        // Mapeia a coluna 'sexo' do banco de dados para definir o ícone correto
                        final sexoStr = paciente['sexo']?.toString().toUpperCase() ?? 'M';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF9CC9BC),
                                      child: Icon(
                                        sexoStr == 'F' || sexoStr == 'FEMININO' ? Icons.face_3 : Icons.face,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        nomeStr,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 14),
                                const Divider(height: 1, color: Colors.grey),
                                const SizedBox(height: 14),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildActionButton(
                                      label: 'Editar',
                                      color: const Color(0xFFCE9E43),
                                      onTap: () async {
                                        final atualizou = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditarPacientePage(pacienteId: idStr),
                                          ),
                                        );
                                        if (atualizou == true) {
                                          setState(() {});
                                        }
                                      },
                                    ),
                                    _buildActionButton(
                                      label: 'Excluir',
                                      color: const Color(0xFFE57373),
                                      onTap: () => _confirmarExclusao(context, idStr, nomeStr),
                                    ),
                                  ],
                                ),
                              ],
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