import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditarPacientePage extends StatefulWidget {
  final String pacienteId;

  const EditarPacientePage({super.key, required this.pacienteId});

  @override
  State<EditarPacientePage> createState() => _EditarPacientePageState();
}

class _EditarPacientePageState extends State<EditarPacientePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos baseados nas colunas do seu banco de dados
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _idadeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascimentoController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();

  String _sexoSelecionado = 'M'; // Padrão inicial
  String _nomeProfissional = 'Profissional';
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _idadeController.dispose();
    _telefoneController.dispose();
    _dataNascimentoController.dispose();
    _enderecoController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  // Carrega os dados do profissional (cabeçalho) e do paciente simultaneamente
  Future<void> _inicializarDados() async {
    try {
      final user = _supabase.auth.currentUser;
      
      // 1. Busca nome do profissional
      if (user != null) {
        final dadosPerfil = await _supabase
            .from('perfis')
            .select('nome')
            .eq('id', user.id)
            .maybeSingle();
        if (dadosPerfil != null && dadosPerfil['nome'] != null) {
          _nomeProfissional = dadosPerfil['nome'];
        }
      }

      // 2. Busca dados cadastrais do paciente
      final dadosPaciente = await _supabase
          .from('pacientes')
          .select()
          .eq('id', widget.pacienteId)
          .single();

      _nomeController.text = dadosPaciente['nome'] ?? '';
      _idadeController.text = dadosPaciente['idade']?.toString() ?? '';
      _telefoneController.text = dadosPaciente['telefone'] ?? '';
      _dataNascimentoController.text = dadosPaciente['data_nascimento'] ?? '';
      _enderecoController.text = dadosPaciente['endereco'] ?? '';
      _cpfController.text = dadosPaciente['cpf'] ?? '';
      
      final sexoBanco = dadosPaciente['sexo']?.toString().toUpperCase() ?? 'M';
      _sexoSelecionado = (sexoBanco == 'F' || sexoBanco == 'FEMININO') ? 'F' : 'M';

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  // Envia as alterações para o Supabase
  Future<void> _atualizarCadastro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      await _supabase.from('pacientes').update({
        'nome': _nomeController.text.trim(),
        'idade': int.tryParse(_idadeController.text.trim()),
        'telefone': _telefoneController.text.trim(),
        'data_nascimento': _dataNascimentoController.text.trim().isEmpty ? null : _dataNascimentoController.text.trim(),
        'endereco': _enderecoController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'sexo': _sexoSelecionado,
      }).eq('id', widget.pacienteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro atualizado com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Retorna true para sinalizar que houve alteração
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // Estilização padrão dos inputs do formulário
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      prefixIcon: Icon(icon, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCE9E43), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4), // Verde-menta padrão do seu app
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
          
          // Conteúdo Dinâmico
          Column(
            children: [
              // Cabeçalho Padrão do Sistema
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

              // Título da Seção
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Editar cadastro',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 15),

              // Formulário de Cadastro
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE9E43))))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nomeController,
                                decoration: _buildInputDecoration('Nome Completo', Icons.badge),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Insira o nome' : null,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      controller: _idadeController,
                                      keyboardType: TextInputType.number,
                                      decoration: _buildInputDecoration('Idade', Icons.calendar_today),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade400),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _sexoSelecionado,
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(value: 'M', child: Text('Masculino')),
                                            DropdownMenuItem(value: 'F', child: Text('Feminino')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _sexoSelecionado = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _telefoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _buildInputDecoration('Telefone / WhatsApp', Icons.phone),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _dataNascimentoController,
                                keyboardType: TextInputType.datetime,
                                decoration: _buildInputDecoration('Data de Nascimento (AAAA-MM-DD)', Icons.cake),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _cpfController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('CPF', Icons.credit_card),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _enderecoController,
                                maxLines: 2,
                                decoration: _buildInputDecoration('Endereço Residencial', Icons.home),
                              ),
                              const SizedBox(height: 24),
                              
                              // Botão de Salvar
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _salvando ? null : _atualizarCadastro,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCE9E43), // Dourado padrão do app
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Colors.black, width: 0.8),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _salvando
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Salvar Alterações',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
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