import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalhe_paciente_page.dart'; 

class PacientesPage extends StatefulWidget {
  const PacientesPage({super.key});

  @override
  State<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends State<PacientesPage> {
  final TextEditingController _searchController = TextEditingController();
  
  // Variável para armazenar o termo digitado na pesquisa
  String _filtroPesquisa = '';

  // Instância do cliente Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável para armazenar o nome do profissional ativo
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional(); // Dispara a busca do nome real assim que a tela abre
  }

  // Função de busca integrada no escopo da tela
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definimos a query base apontando para a nossa tabela 'pacientes' ordenando por nome
    var query = _supabase.from('pacientes').stream(primaryKey: ['id']).order('nome');

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
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          
          // Conteúdo da Tela
          Column(
            children: [
              // 1. CABEÇALHO PADRÃO DO SISTEMA
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
                      onPressed: () {
                        Navigator.pop(context); // Retorna para o painel principal
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // 2. TÍTULO DA SEÇÃO ("Busca de pacientes")
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Busca de pacientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 3. CAMPO DE PESQUISA (Nome ou CPF ou Telefone)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Nome, CPF ou Tel',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      // Ícone para limpar o texto da busca caso haja algo digitado
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filtroPesquisa = '';
                              });
                            },
                          )
                        : null,
                    ),
                    onChanged: (value) {
                      // Atualiza o estado do filtro conforme digita
                      setState(() {
                        _filtroPesquisa = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 4. LISTA REAL DE PACIENTES VINDA DO SUPABASE
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: query,
                        builder: (context, snapshot) {
                          // Caso esteja carregando a conexão inicial
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFFC5993F)),
                            );
                          }

                          // Se houver algum erro na busca de dados ou RLS
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Erro ao carregar dados: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            );
                          }

                          // Captura a lista completa de registros
                          final todosPacientes = snapshot.data ?? [];

                          // Filtra localmente baseado no Nome, CPF ou Telefone inserido no input
                          final pacientesFiltrados = todosPacientes.where((paciente) {
                            final nome = (paciente['nome'] ?? '').toString().toLowerCase();
                            final cpf = (paciente['cpf'] ?? '').toString().toLowerCase();
                            final telefone = (paciente['telefone'] ?? '').toString().toLowerCase();
                            return nome.contains(_filtroPesquisa) ||
                                   cpf.contains(_filtroPesquisa) ||
                                   telefone.contains(_filtroPesquisa);
                          }).toList();

                          // Caso a tabela esteja limpa ou nenhum registro atenda o filtro de busca
                          if (pacientesFiltrados.isEmpty) {
                            return const Center(
                              child: Text(
                                'Nenhum paciente encontrado.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12.0),
                            itemCount: pacientesFiltrados.length,
                            itemBuilder: (context, index) {
                              final paciente = pacientesFiltrados[index];
                              
                              // Captura o sexo original salvo para definir o ícone correto ('M' ou 'F')
                              final String sexo = (paciente['sexo'] ?? '').toString().toUpperCase();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: GestureDetector(
                                  onTap: () {
                                    // Encaminha as credenciais do paciente para uso na tela de prontuário/detalhes
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetalhePacientePage(
                                          idPaciente: paciente['id'],
                                          nomePaciente: paciente['nome'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9CC9BC), // Fundo verde suave do card
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        // Escolha dinâmica do avatar baseado no sexo salvo no banco
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.white,
                                          child: Icon(
                                            sexo.startsWith('F') ? Icons.face_3 : Icons.face,
                                            size: 22,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        
                                        // Nome real do Paciente mapeado da coluna do banco
                                        Expanded(
                                          child: Text(
                                            paciente['nome'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
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