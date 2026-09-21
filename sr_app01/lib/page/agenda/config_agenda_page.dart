import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfigAgendaPage extends StatefulWidget {
  const ConfigAgendaPage({super.key});

  @override
  State<ConfigAgendaPage> createState() => _ConfigAgendaPageState();
}

class _ConfigAgendaPageState extends State<ConfigAgendaPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _estaCarregando = true;
  String _nomeProfissional = 'Carregando...';

  // Controle dos dias de trabalho selecionados
  final Map<String, bool> _diasTrabalho = {
    'Seg': true,
    'Ter': true,
    'Qua': true,
    'Qui': true,
    'Sex': true,
    'Sáb': false,
    'Dom': false,
  };

  // Controladores dos horários
  final TextEditingController _inicioController = TextEditingController(text: '08:00');
  final TextEditingController _almocoInicioController = TextEditingController(text: '12:00');
  final TextEditingController _almocoFimController = TextEditingController(text: '13:30');
  final TextEditingController _fimController = TextEditingController(text: '18:00');

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  @override
  void dispose() {
    _inicioController.dispose();
    _almocoInicioController.dispose();
    _almocoFimController.dispose();
    _fimController.dispose();
    super.dispose();
  }

  Future<void> _inicializarDados() async {
    await _buscarNomeProfissional();
    await _carregarConfiguracoes();
  }

  // Busca o nome do profissional na tabela 'perfis'
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

  // Carrega os dados salvos previamente do banco de dados
  Future<void> _carregarConfiguracoes() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final dados = await _supabase
          .from('config_agenda')
          .select()
          .eq('id_usuario', user.id)
          .maybeSingle();

      if (dados != null) {
        setState(() {
          _diasTrabalho['Seg'] = dados['seg'] ?? true;
          _diasTrabalho['Ter'] = dados['ter'] ?? true;
          _diasTrabalho['Qua'] = dados['qua'] ?? true;
          _diasTrabalho['Qui'] = dados['qui'] ?? true;
          _diasTrabalho['Sex'] = dados['sex'] ?? true;
          _diasTrabalho['Sáb'] = dados['sab'] ?? false;
          _diasTrabalho['Dom'] = dados['dom'] ?? false;

          _inicioController.text = dados['horario_inicio'] ?? '08:00';
          _fimController.text = dados['horario_fim'] ?? '18:00';
          _almocoInicioController.text = dados['pausa_inicio'] ?? '12:00';
          _almocoFimController.text = dados['pausa_fim'] ?? '13:30';
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar configurações da agenda: $e');
    } finally {
      setState(() => _estaCarregando = false);
    }
  }

  // Envia e salva as alterações via Upsert
  Future<void> _salvarAgenda() async {
    setState(() => _estaCarregando = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      await _supabase.from('config_agenda').upsert({
        'id_usuario': user.id,
        'seg': _diasTrabalho['Seg'],
        'ter': _diasTrabalho['Ter'],
        'qua': _diasTrabalho['Qua'],
        'qui': _diasTrabalho['Qui'],
        'sex': _diasTrabalho['Sex'],
        'sab': _diasTrabalho['Sáb'],
        'dom': _diasTrabalho['Dom'],
        'horario_inicio': _inicioController.text.trim(),
        'horario_fim': _fimController.text.trim(),
        'pausa_inicio': _almocoInicioController.text.trim(),
        'pausa_fim': _almocoFimController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agenda salva com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _estaCarregando = false);
    }
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black, width: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4),
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/ondas_douradas.png',
              fit: BoxFit.cover,
            ),
          ),
          _estaCarregando
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCE9E43)))
              : SingleChildScrollView(
                  child: Column(
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

                      // 2. TÍTULO DA TELA
                      Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4C47A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Configurar Agenda',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // 3. CARD: DIAS DE TRABALHO
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dias de Atendimento',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: _diasTrabalho.keys.map((dia) {
                                  bool selecionado = _diasTrabalho[dia] ?? false;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _diasTrabalho[dia] = !selecionado;
                                          });
                                        },
                                        child: Container(
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: selecionado ? const Color(0xFF9CC9BC) : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: selecionado ? Colors.black : Colors.grey.shade400,
                                              width: selecionado ? 1.2 : 0.8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              dia,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                                                color: selecionado ? Colors.black : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 4. CARD: HORÁRIOS DE ATENDIMENTO E PAUSAS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Horários do Expediente',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildTimeField(label: 'Início', controller: _inicioController),
                                  _buildTimeField(label: 'Fim do Turno', controller: _fimController),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'Intervalo / Almoço',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildTimeField(label: 'Início Pausa', controller: _almocoInicioController),
                                  _buildTimeField(label: 'Fim Pausa', controller: _almocoFimController),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 5. BOTÃO DE SALVAR CONFIGURAÇÕES
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.55,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _salvarAgenda,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCE9E43),
                            foregroundColor: Colors.black,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Colors.black, width: 1.2),
                            ),
                          ),
                          child: const Text(
                            'Salvar Agenda',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}