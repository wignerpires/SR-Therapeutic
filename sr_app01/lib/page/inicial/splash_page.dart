import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart'; // Certifique-se de importar a sua tela de login aqui

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    
    // Configura o temporizador para esperar 3 segundos e mudar de tela
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Navigator.pushReplacement remove a Splash da pilha, 
        // assim o usuário não volta para ela se apertar o botão "Voltar" do celular.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D24), // Fundo Verde Escuro
      body: Stack(
        children: [
          // Imagem de ondas posicionada na parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/ondas_douradas.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Conteúdo Centralizado (Texto e Carregamento)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Iniciais estilizadas "S.R."
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
                const SizedBox(height: 16),
                // Texto de carregamento miúdo
                Text(
                  'L O A D I N G . . .',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFFC0A060).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Indicador de Bolinhas Personalizado
                const DotProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget das bolinhas de progresso
class DotProgressIndicator extends StatelessWidget {
  const DotProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(15, (index) {
        bool isActive = index < 7; 
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : const Color(0xFF8B6B32),
          ),
        );
      }),
    );
  }
}