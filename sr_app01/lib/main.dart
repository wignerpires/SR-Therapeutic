import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sr_app01/page/inicial/splash_page.dart'; // Importa a Splash
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa as datas no padrão Português do Brasil
  await initializeDateFormatting('pt_BR', null);

  await Supabase.initialize(
    url: 'https://xtodxbxhaogmkqaatonz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0b2R4YnhoYW9nbWtxYWF0b256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMjk5NjksImV4cCI6MjA5NzkwNTk2OX0.CPLnvGpEwaGyepetfzOQxfzOAeIn5rCkklVmkQYX0n0',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'S.R. Therapeutic',
      
      // Configuração para Português
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      home: const SplashPage(), // Começa na Splash
    );
  }
}