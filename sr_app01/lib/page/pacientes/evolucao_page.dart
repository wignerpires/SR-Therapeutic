import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EvolucaoPage extends StatefulWidget {
  final String pacienteId;
  final String nomePaciente;
  final String diagnosticoMtc;
  final String objetivoTratamento;

  const EvolucaoPage({
    super.key,
    required this.pacienteId,
    required this.nomePaciente,
    this.diagnosticoMtc = '',
    this.objetivoTratamento = '',
  });

  @override
  State<EvolucaoPage> createState() => _EvolucaoPageState();
}

class _EvolucaoPageState extends State<EvolucaoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Controllers dos campos fixos
  final TextEditingController _diagController = TextEditingController();
  final TextEditingController _objController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();

  String _nomeProfissional = 'Carregando...';
  bool _estaSalvando = false;

  // Estado para a situação de alta/melhora pós-tratamento
  String _resultadoTratamento = ''; 

  // Estrutura para controlar as 10 sessões da grade
  final List<Map<String, dynamic>> _sessoes = List.generate(10, (index) {
    return {
      'sessao': index + 1,
      'data': TextEditingController(),
      'dor': TextEditingController(),
      'evolucao': TextEditingController(),
      'pontos_tecnicas': TextEditingController(),
    };
  });

  @override
  void initState() {
    super.initState();
    _diagController.text = widget.diagnosticoMtc;
    _objController.text = widget.objetivoTratamento;
    _buscarNomeProfissional();
  }

  @override
  void dispose() {
    _diagController.dispose();
    _objController.dispose();
    _obsController.dispose();
    for (var sessao in _sessoes) {
      sessao['data'].dispose();
      sessao['dor'].dispose();
      sessao['evolucao'].dispose();
      sessao['pontos_tecnicas'].dispose();
    }
    super.dispose();
  }

  // Função que busca o nome do profissional logado na tabela 'perfis'
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

  // Função oficial que salva as sessões na nova tabela 'sessoes_evolucao'
  Future<void> _salvarEvolucaoNoBanco() async {
    // Validação básica para não salvar uma ficha totalmente em branco
    bool temConteudo = false;
    for (var s in _sessoes) {
      if (s['data'].text.isNotEmpty || s['dor'].text.isNotEmpty || s['evolucao'].text.isNotEmpty || s['pontos_tecnicas'].text.isNotEmpty) {
        temConteudo = true;
        break;
      }
    }

    if (!temConteudo && _diagController.text.isEmpty && _objController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha ao menos uma sessão ou campo antes de salvar!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _estaSalvando = true;
    });

    try {
      List<Map<String, dynamic>> linhasParaInserir = [];

      // Passa por cada uma das 10 sessões guardando apenas as que foram preenchidas
      for (var s in _sessoes) {
        if (s['data'].text.isNotEmpty || s['dor'].text.isNotEmpty || s['evolucao'].text.isNotEmpty || s['pontos_tecnicas'].text.isNotEmpty) {
          
          // Tenta converter a dor para número inteiro, se falhar ou estiver vazio deixa nulo
          int? dorNivel = int.tryParse(s['dor'].text);

          linhasParaInserir.add({
            'paciente_id': widget.pacienteId,
            'diagnostico_mtc': _diagController.text,
            'objetivo_tratamento': _objController.text,
            'numero_sessao': s['sessao'],
            'data_sessao': s['data'].text,
            'dor_nivel': dorNivel,
            'evolucao_detalhes': s['evolucao'].text,
            'pontos_tecnicas': s['pontos_tecnicas'].text,
            'situacao_pos_tratamento': _resultadoTratamento.isNotEmpty ? _resultadoTratamento : null,
            'observacoes_gerais': _obsController.text,
          });
        }
      }

      // Se o usuário preencheu apenas os dados de cima (Diagnóstico/Objetivo) mas nenhuma sessão ainda
      if (linhasParaInserir.isEmpty) {
        linhasParaInserir.add({
          'paciente_id': widget.pacienteId,
          'diagnostico_mtc': _diagController.text,
          'objetivo_tratamento': _objController.text,
          'numero_sessao': 0, // 0 indica que é um registro inicial sem sessão vinculada
          'data_sessao': '',
          'dor_nivel': null,
          'evolucao_detalhes': '',
          'pontos_tecnicas': '',
          'situacao_pos_tratamento': _resultadoTratamento.isNotEmpty ? _resultadoTratamento : null,
          'observacoes_gerais': _obsController.text,
        });
      }

      // Executa um insert em lote (Bulk Insert) enviando todas as sessões de uma vez só
      await _supabase.from('sessoes_evolucao').insert(linhasParaInserir);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evolução clínica salva com sucesso no banco de dados!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Fecha a tela e retorna
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar evolução: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _estaSalvando = false;
        });
      }
    }
  }

  // Widgets auxiliares de interface (Design Verde-Menta / Dourado)
  Widget _buildTopField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black, width: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessaoCard(Map<String, dynamic> sessao) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black, width: 0.8),
      ),
      child: ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        title: Text(
          'Sessão ${sessao['sessao']}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(child: _buildInlineField('Data', sessao['data'], hint: 'Ex: 26/06')),
              const SizedBox(width: 10),
              Expanded(child: _buildInlineField('Dor (0-10)', sessao['dor'], hint: 'Ex: 5', keyboardType: TextInputType.number)),
            ],
          ),
          _buildInlineField('Evolução do Paciente', sessao['evolucao']),
          _buildInlineField('Pontos / Técnicas', sessao['pontos_tecnicas']),
        ],
      ),
    );
  }

  Widget _buildInlineField(String label, TextEditingController controller, {String hint = '', TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.black54),
          fillColor: Colors.grey.shade50,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCE9E43), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildResultadoRadio(String valor, String label) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 16, color: Colors.black)),
      value: valor,
      groupValue: _resultadoTratamento,
      activeColor: const Color(0xFFCE9E43),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: (value) {
        setState(() {
          _resultadoTratamento = value ?? '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FD3C4),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // CABEÇALHO DO PROFISSIONAL
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
                    child: Icon(Icons.assignment, size: 28, color: Colors.grey),
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

            const SizedBox(height: 14),

            // TÍTULO DA SEÇÃO
            Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE4C47A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 0.5),
              ),
              child: const Text(
                'Ficha de Evolução Clínica',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),

            // FORMULÁRIO DE SEÇÕES ROLÁVEL
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Paciente: ${widget.nomePaciente}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  _buildTopField('Diagnóstico Energético (MTC)', _diagController),
                  _buildTopField('Objetivo do Tratamento', _objController),

                  const SizedBox(height: 16),
                  const Text(
                    'Evolução nas Sessões',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 6),

                  // Renderiza a lista de 1 a 10 expansível
                  ..._sessoes.map((s) => _buildSessaoCard(s)),

                  const SizedBox(height: 16),
                  const Text(
                    'Após Tratamento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildResultadoRadio('MELHOROU_MUITO', 'Melhorou muito'),
                        _buildResultadoRadio('MELHOROU', 'Melhorou'),
                        _buildResultadoRadio('SEM_ALTERACAO', 'Sem alteração'),
                        _buildResultadoRadio('PIOROU', 'Piorou'),
                        _buildResultadoRadio('ALTA', 'Alta'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildTopField('Observações Gerais', _obsController),
                  const SizedBox(height: 24),

                  // BOTÃO DE ENVIO COM FEEDBACK DE SALVAMENTO
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.65,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _estaSalvando ? null : _salvarEvolucaoNoBanco,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE9E43),
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.black, width: 1.2),
                          ),
                        ),
                        child: _estaSalvando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Salvar Evolução',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}