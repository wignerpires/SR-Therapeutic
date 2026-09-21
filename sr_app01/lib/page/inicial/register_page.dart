import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores dos campos
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();

  // Estado do checkbox "Aceito os termos de uso"
  bool _aceitoTermos = false;
  
  // Controle de loading para o processo de cadastro
  bool _isLoading = false;

  // Instância do Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Função que faz a mágica acontecer no Supabase
  Future<void> _cadastrarUsuario() async {
    // 1. Validações básicas
    if (!_aceitoTermos) {
      _mostrarMensagem('Você precisa aceitar os termos de uso.');
      return;
    }

    if (_nomeController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _senhaController.text.trim().isEmpty) {
      _mostrarMensagem('Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Criar o usuário no Auth do Supabase
      final AuthResponse response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      final String? userId = response.user?.id;

      // 3. Se o usuário foi criado com sucesso no Auth, salva o Nome e Telefone na tabela 'perfis'
      if (userId != null) {
        await _supabase.from('perfis').insert({
          'id': userId,
          'nome': _nomeController.text.trim(),
          'telefone': _telefoneController.text.trim(),
        });

        _mostrarMensagem('Cadastro realizado com sucesso!');
        
        if (mounted) {
          Navigator.pop(context); // Volta para a tela de Login
        }
      }
    } on AuthException catch (error) {
      // Erros específicos do Supabase Auth (ex: e-mail já cadastrado, senha fraca)
      _mostrarMensagem(error.message);
    } catch (error) {
      // Qualquer outro erro inesperado
      _mostrarMensagem('Ocorreu um erro inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper simples para exibir lanchonete de avisos (SnackBar)
  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D24), // Fundo Verde Escuro
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
              errorBuilder: (context, error, stackTrace) => const SizedBox(), // Evita quebrar se a imagem sumir temporariamente
            ),
          ),
          
          // Corpo com scroll para não quebrar com o teclado
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logotipo "S.R."
                    const Text(
                      'S.R.',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE4C47A),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    // Subtítulo "Therapeutic"
                    const Text(
                      'Therapeutic',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        color: Color(0xFFC0A060),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Campo: Nome Completo
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        hintText: 'Nome completo',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo: E-mail
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'E-mail',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo: Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Senha',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo: Telefone
                    TextField(
                      controller: _telefoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Telefone',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Checkbox "Aceito os termos de uso"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Theme(
                          data: ThemeData(unselectedWidgetColor: Colors.white),
                          child: Checkbox(
                            value: _aceitoTermos,
                            activeColor: const Color(0xFFC0A060),
                            checkColor: Colors.black,
                            onChanged: _isLoading 
                                ? null // Desabilita o checkbox enquanto carrega
                                : (bool? value) {
                                    setState(() {
                                      _aceitoTermos = value ?? false;
                                    });
                                  },
                          ),
                        ),
                        const Text(
                          'Aceito os termos de uso',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botão Cadastrar com feedback visual de carregamento
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _cadastrarUsuario,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC5993F),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white, width: 1),
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
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}