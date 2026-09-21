import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sr_app01/page/inicial/register_page.dart';
import 'package:sr_app01/page/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o que o usuário digita
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  
  // Estado do checkbox "Lembrar senha"
  bool _lembrarSenha = false;
  bool _isLoading = false;

  // Instância do cliente Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregarCredenciaisSalvas();
  }

  // Carrega o e-mail e senha salvos localmente se o usuário marcou "Lembrar" anteriormente
  Future<void> _carregarCredenciaisSalvas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? '';
      _senhaController.text = prefs.getString('saved_password') ?? '';
      _lembrarSenha = prefs.getBool('remember_me') ?? false;
    });
  }

  // Salva ou remove os dados localmente baseado na escolha do checkbox
  Future<void> _salvarCredenciais() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lembrarSenha) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _senhaController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  // Função para realizar o Login
  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _mostrarMensagem('Por favor, preencha o e-mail e a senha.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Faz a requisição de login no Supabase Auth
      await _supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      // Salva localmente as credenciais se o checkbox estiver ativo
      await _salvarCredenciais();

      if (mounted) {
        // Redireciona para o Painel Principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on AuthException catch (error) {
      // Tratamento refinado de erros comuns do Supabase Auth
      String mensagemErro = 'Falha ao autenticar.';
      
      // Dependendo da versão/configuração do Supabase, o código ou a mensagem muda
      if (error.message.contains('Invalid login credentials') || error.statusCode == '400') {
        mensagemErro = 'E-mail inexistente ou senha incorreta.';
      } else if (error.message.contains('Email not confirmed')) {
        mensagemErro = 'Por favor, confirme seu e-mail para poder acessar o sistema.';
      } else {
        mensagemErro = error.message;
      }
      
      _mostrarMensagem(mensagemErro);
    } catch (error) {
      _mostrarMensagem('Ocorreu um erro inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Função para enviar o link de recuperação de senha por e-mail
  Future<void> _recuperarSenha(String email) async {
    if (email.trim().isEmpty) {
      _mostrarMensagem('Digite um e-mail válido.');
      return;
    }

    try {
      // O Supabase envia um link para o e-mail inserido resetar a senha
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _mostrarMensagem('Link de recuperação enviado para o e-mail informado!');
    } catch (error) {
      _mostrarMensagem('Erro ao tentar enviar recuperação: $error');
    }
  }

  // Modal (Pop-up) para o usuário digitar o e-mail de recuperação
  void _mostrarDialogRecuperacao() {
    final TextEditingController recoveryEmailController = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF123D24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE4C47A))),
        title: const Text('Recuperar Senha', style: TextStyle(color: Color(0xFFE4C47A), fontFamily: 'PlayfairDisplay')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insira o seu e-mail de cadastro. Enviaremos um link para redefinir sua senha.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: recoveryEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Seu e-mail',
                hintStyle: const TextStyle(color: Colors.grey),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5993F)),
            onPressed: () {
              Navigator.pop(context);
              _recuperarSenha(recoveryEmailController.text);
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D24), // Fundo Verde Escuro
      body: Stack(
        children: [
          // Ondas douradas fixadas no fundo inferior
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
          
          // Conteúdo com rolagem (evita erros quando o teclado abre)
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
                    const SizedBox(height: 40),

                    // Campo de E-mail
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
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

                    // Campo de Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: true,
                      enabled: !_isLoading,
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
                    const SizedBox(height: 12),

                    // Linha do Checkbox "Lembrar senha"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Theme(
                          data: ThemeData(unselectedWidgetColor: Colors.white),
                          child: Checkbox(
                            value: _lembrarSenha,
                            activeColor: const Color(0xFFC0A060),
                            checkColor: Colors.black,
                            onChanged: _isLoading
                                ? null
                                : (bool? value) {
                                    setState(() {
                                      _lembrarSenha = value ?? false;
                                    });
                                  },
                          ),
                        ),
                        const Text(
                          'Lembrar senha',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Botão de recuperar senha (Texto clicável em dourado)
                    TextButton(
                      onPressed: _isLoading ? null : _mostrarDialogRecuperacao,
                      child: const Text(
                        'Esqueceu sua senha?',
                        style: TextStyle(
                          color: Color(0xFFE4C47A),
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botão Entrar com indicador de progresso
                    SizedBox(
                      width: 180,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fazerLogin,
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
                                'Entrar',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botão Criar nova conta
                    SizedBox(
                      width: 260,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC5993F),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: const Text(
                          'Criar nova conta',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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