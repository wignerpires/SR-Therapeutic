import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroPacientePage extends StatefulWidget {
  const CadastroPacientePage({super.key});

  @override
  State<CadastroPacientePage> createState() => _CadastroPacientePageState();
}

class _CadastroPacientePageState extends State<CadastroPacientePage> {
  // Controladores para capturar os dados de cada campo
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _idadeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _nascimentoController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _sexoController = TextEditingController();

  // Controle de loading do banco de dados
  bool _isLoading = false;

  // Instância do cliente Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variável para armazenar o nome do profissional ativo
  String _nomeProfissional = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional(); // Dispara a busca do nome real assim que a tela abre
  }

  // A sua função de busca integrada perfeitamente no escopo da tela
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

  // Função para salvar o paciente no Supabase
  Future<void> _salvarPaciente() async {
    final nome = _nomeController.text.trim();

    // Validação básica de campo obrigatório
    if (nome.isEmpty) {
      _mostrarMensagem('O nome do paciente é obrigatório.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Tenta converter a string da idade para inteiro com segurança
      final int? idadeInt = int.tryParse(_idadeController.text.trim());

      // Insere os dados na tabela 'pacientes' do Supabase
      // O 'usuario_id' será preenchido automaticamente pelo banco graças ao 'default auth.uid()' que definimos no SQL
      await _supabase.from('pacientes').insert({
        'nome': nome,
        'idade': idadeInt,
        'telefone': _telefoneController.text.trim(),
        'data_nascimento': _nascimentoController.text.trim(),
        'endereco': _enderecoController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'sexo': _sexoController.text.trim(),
      });

      _mostrarMensagem('Paciente cadastrado com sucesso!');

      if (mounted) {
        Navigator.pop(context); // Retorna para a tela anterior (Central de Pacientes)
      }
    } catch (error) {
      _mostrarMensagem('Erro ao cadastrar paciente: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // SnackBar utilitário para mensagens rápidas
  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void dispose() {
    // Limpeza dos controladores ao fechar a tela
    _nomeController.dispose();
    _idadeController.dispose();
    _telefoneController.dispose();
    _nascimentoController.dispose();
    _enderecoController.dispose();
    _cpfController.dispose();
    _sexoController.dispose();
    super.dispose();
  }

  // Widget utilitário para criar os campos de input arredondados e brancos
  Widget _buildTextField(String hint, TextEditingController controller, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: !_isLoading, // Bloqueia digitação enquanto salva
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
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
                        _nomeProfissional, // Substituído o nome fixo pela variável dinâmica
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

              // 2. TÍTULO DA TELA
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Cadastro de pacientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 10),

              // 3. FORMULÁRIO COM SCROLL
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
                  child: Column(
                    children: [
                      _buildTextField('Nome completo', _nomeController),
                      _buildTextField('Idade', _idadeController, type: TextInputType.number),
                      _buildTextField('Telefone', _telefoneController, type: TextInputType.phone),
                      _buildTextField('Data de nascimento', _nascimentoController, type: TextInputType.datetime),
                      _buildTextField('Endereço', _enderecoController),
                      _buildTextField('CPF', _cpfController, type: TextInputType.number),
                      _buildTextField('Sexo', _sexoController),
                      
                      const SizedBox(height: 30),

                      // BOTÃO CADASTRAR com indicador de processamento
                      SizedBox(
                        width: 180,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _salvarPaciente,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC5993F),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.black, width: 1),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Cadastrar',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40), // Espaço extra para não encostar no final
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