import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importação do Supabase

class AnamnesePage extends StatefulWidget {
  final String pacienteId; // Alterado para String (UUID) para bater com o banco
  final String nomePaciente;

  const AnamnesePage({
    super.key,
    required this.pacienteId,
    required this.nomePaciente,
  });

  @override
  State<AnamnesePage> createState() => _AnamnesePageState();
}

class _AnamnesePageState extends State<AnamnesePage> {
  // Instância do Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // Para armazenar os textos de cada campo
  final Map<String, TextEditingController> _controllers = {};
  
  String _nomeProfissional = 'Carregando...'; // Estado inicial do cabeçalho
  bool _estaSalvando = false;

  @override
  void initState() {
    super.initState();
    // Inicializa o nome do paciente direto no controller de identificação
    _controllers['nome'] = TextEditingController(text: widget.nomePaciente);
    
    // Busca o nome do usuário logado na tabela 'perfis'
    _buscarNomeProfissional();

    // Inicialização genérica de todos os campos estruturados para facilitar a gestão
    final campos = [
      'nascimento', 'sexo', 'estado_civil', 'profissao', 'telefone', 'data_consulta',
      'qp_motivo', 'qp_tempo', 'qp_piora', 'qp_melhora', 'qp_tratamento',
      'hda_inicio', 'hda_frequencia', 'hda_intensidade', 'hda_localizacao', 'hda_caracteristica', 'hda_piora_mtc', 'hda_relacao',
      'hist_previas', 'hist_cirurgias', 'hist_internacoes', 'hist_traumas', 'hist_familiar',
      'med_uso', 'med_hormonios', 'med_fitoterápicos', 'med_tempo',
      'mtc_sono', 'mtc_acorda', 'mtc_sonhos', 'mtc_insonia',
      'mtc_fome', 'mtc_inchaco', 'mtc_azia', 'mtc_preferencia',
      'mtc_sede', 'mtc_sede_pref',
      'mtc_intestino_freq', 'mtc_fezes',
      'mtc_urina_cor', 'mtc_urina_freq', 'mtc_urina_dor',
      'mtc_sudorese_esp', 'mtc_sudorese_not',
      'emocional_detalhes', 'ciclo_menarca', 'ciclo_regular', 'ciclo_tpm', 'ciclo_colicas', 'ciclo_fluxo', 'ciclo_menopausa',
      'musc_localizacao', 'musc_tipo', 'musc_limitacao', 'musc_rigidez', 'musc_piora_clima',
      'exame_lingua_cor', 'exame_lingua_saburra', 'exame_lingua_forma', 'exame_lingua_umidade',
      'exame_pulso_prof', 'exame_pulso_vel', 'exame_pulso_volume', 'exame_pulso_tipo',
      'hab_alimentacao', 'hab_alcool', 'hab_tabaco', 'hab_exercicio', 'hab_descanso',
      'diag_energetico', 'plano_objetivo', 'plano_pontos', 'plano_freq', 'plano_complementares'
    ];

    for (var campo in campos) {
      if (!_controllers.containsKey(campo)) {
        _controllers[campo] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Função que busca o nome do profissional na tabela 'perfis'
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

  // Função oficial que grava a Anamnese na tabela 'historico_paciente' do Supabase
  Future<void> _salvarAnamneseNoBanco() async {
    setState(() {
      _estaSalvando = true;
    });

    try {
      // 1. Coleta os dados de todos os TextFields em um Map
      Map<String, String> dadosAnamnese = {};
      _controllers.forEach((key, controller) {
        dadosAnamnese[key] = controller.text;
      });

      // 2. Insere o registro diretamente na tabela que você criou no Supabase
      await _supabase.from('historico_paciente').insert({
        'paciente_id': widget.pacienteId,      // Vincula ao UUID do paciente
        'tipo_registro': 'ANAMNESE',           // Identifica o tipo de ficha
        'dados': dadosAnamnese,                // O próprio SDK do Supabase já converte o Map em JSONB automaticamente!
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anamnese salva com sucesso no perfil do paciente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Retorna fechando a tela
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar no banco: $e'),
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

  // Widget utilitário para gerar os campos de texto internos dos blocos
  Widget _buildField(String label, String key, {String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _controllers[key],
            decoration: InputDecoration(
              hintText: hint,
              fillColor: Colors.grey.shade50,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget utilitário para criar as categorias expandíveis (ExpansionTile)
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.black, width: 0.8),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
            title: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            childrenPadding: const EdgeInsets.all(12),
            children: children,
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/ondas_douradas.png',
              fit: BoxFit.cover,
            ),
          ),
          
          Column(
            children: [
              // 1. CABEÇALHO COM NOME DO PROFISSIONAL BUSCADO DINAMICAMENTE
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
                        _nomeProfissional, // Exibe o valor do estado atualizado pela função
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
              
              const SizedBox(height: 18),

              // 2. TÍTULO DA SEÇÃO
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4C47A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Ficha de Anamnese',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 14),

              // 3. LISTA DAS SEÇÕES
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildSection(title: '1. Identificação', children: [
                      _buildField('Nome completo', 'nome'),
                      _buildField('Data de nascimento / Idade', 'nascimento'),
                      _buildField('Sexo', 'sexo'),
                      _buildField('Estado civil', 'estado_civil'),
                      _buildField('Profissão', 'profissao'),
                      _buildField('Telefone', 'telefone'),
                      _buildField('Data da consulta', 'data_consulta'),
                    ]),

                    _buildSection(title: '2. Queixa Principal', children: [
                      _buildField('Qual o principal motivo da consulta?', 'qp_motivo'),
                      _buildField('Há quanto tempo começou?', 'qp_tempo'),
                      _buildField('O que piora?', 'qp_piora'),
                      _buildField('O que melhora?', 'qp_melhora'),
                      _buildField('Já fez tratamento? Qual? Resultado?', 'qp_tratamento'),
                    ]),

                    _buildSection(title: '3. História da Doença Atual (HDA)', children: [
                      _buildField('Início (súbito ou gradual)', 'hda_inicio'),
                      _buildField('Frequência dos sintomas', 'hda_frequencia'),
                      _buildField('Intensidade (0 a 10)', 'hda_intensidade'),
                      _buildField('Localização e irradiação', 'hda_localizacao'),
                      _buildField('Características da dor (pontada, queimação, peso)', 'hda_caracteristica'),
                      _buildField('Horário de piora (MTC)', 'hda_piora_mtc'),
                      _buildField('Relação com emoções, clima ou alimentação', 'hda_relacao'),
                    ]),

                    _buildSection(title: '4. Histórico de Saúde', children: [
                      _buildField('Doenças prévias', 'hist_previas'),
                      _buildField('Cirurgias', 'hist_cirurgias'),
                      _buildField('Internações', 'hist_internacoes'),
                      _buildField('Traumas físicos ou emocionais importantes', 'hist_traumas'),
                      _buildField('Histórico familiar de doenças', 'hist_familiar'),
                    ]),

                    _buildSection(title: '5. Medicações e Suplementos', children: [
                      _buildField('Medicamentos em uso (ex: Ibuprofeno, Trazodona)', 'med_uso'),
                      _buildField('Uso de hormônios', 'med_hormonios'),
                      _buildField('Fitoterápicos / chás', 'med_fitoterápicos'),
                      _buildField('Tempo de uso', 'med_tempo'),
                    ]),

                    _buildSection(title: '6. Avaliação Energética (MTC)', children: [
                      const Text('SONO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCE9E43))),
                      _buildField('Dorme bem?', 'mtc_sono'),
                      _buildField('Acorda durante a noite? Horário?', 'mtc_acorda'),
                      _buildField('Sonhos intensos? Insônia?', 'mtc_insonia'),
                      const SizedBox(height: 8),
                      const Text('APETITE E DIGESTÃO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCE9E43))),
                      _buildField('Fome normal, excessiva ou pouca?', 'mtc_fome'),
                      _buildField('Inchaço abdominal? Azia / refluxo?', 'mtc_inchaco'),
                      _buildField('Preferência por quente ou frio?', 'mtc_preferencia'),
                      const SizedBox(height: 8),
                      const Text('SEDE E EXCREÇÕES', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCE9E43))),
                      _buildField('Pouca / muita sede? Bebidas quentes/frias?', 'mtc_sede'),
                      _buildField('Intestino (Frequência e consistência)', 'mtc_intestino_freq'),
                      _buildField('Urina (Cor, frequência, dor/ardência)', 'mtc_urina_cor'),
                      _buildField('Sudorese (Espontânea ou noturna?)', 'mtc_sudorese_esp'),
                    ]),

                    _buildSection(title: '7. Avaliação Emocional', children: [
                      _buildField('Ansiedade, Estresse, Irritabilidade, Tristeza, Medo', 'emocional_detalhes', hint: 'Zang-Fu: Fígado, Coração, Pulmão, Rins...'),
                    ]),

                    _buildSection(title: '8. Ciclo Menstrual (Se aplicável)', children: [
                      _buildField('Idade da menarca / Regularidade', 'ciclo_menarca'),
                      _buildField('TPM / Cólicas', 'ciclo_tpm'),
                      _buildField('Fluxo (Intenso, escasso, cor) / Menopausa?', 'ciclo_fluxo'),
                    ]),

                    _buildSection(title: '9. Dor e Sistema Muscular', children: [
                      _buildField('Localização e tipo de dor', 'musc_localizacao'),
                      _buildField('Limitação de movimento / Rigidez', 'musc_limitacao'),
                      _buildField('Piora com frio ou umidade?', 'musc_piora_clima'),
                    ]),

                    _buildSection(title: '10. Exame Físico (MTC)', children: [
                      const Text('LÍNGUA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCE9E43))),
                      _buildField('Cor / Saburra', 'exame_lingua_cor'),
                      _buildField('Forma / Umidade', 'exame_lingua_forma'),
                      const SizedBox(height: 8),
                      const Text('PULSO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCE9E43))),
                      _buildField('Profundo / Superficial', 'exame_pulso_prof'),
                      _buildField('Rápido / Lento', 'exame_pulso_vel'),
                      _buildField('Cheio / Vazio / Escorregadio / Fino', 'exame_pulso_volume'),
                    ]),

                    _buildSection(title: '11. Hábitos de Vida', children: [
                      _buildField('Alimentação', 'hab_alimentacao'),
                      _buildField('Consumo de álcool / Tabagismo', 'hab_alcool'),
                      _buildField('Atividade física / Qualidade do descanso', 'hab_exercicio'),
                    ]),

                    _buildSection(title: '12. Diagnóstico Energético (MTC)', children: [
                      _buildField('Conclusão diagnóstica', 'diag_energetico', hint: 'Ex: Estagnação de Qi do Fígado, Deficiência de Yin...'),
                    ]),

                    _buildSection(title: '13. Plano de Tratamento', children: [
                      _buildField('Objetivo terapêutico', 'plano_objetivo'),
                      _buildField('Pontos de acupuntura', 'plano_pontos'),
                      _buildField('Frequência das sessões', 'plano_freq'),
                      _buildField('Técnicas complementares (Ventosa, Moxa, Auriculo, Fito)', 'plano_complementares'),
                    ]),

                    const SizedBox(height: 20),

                    // 4. BOTÃO SALVAR COM PROGRESS INDICATOR
                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.60,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _estaSalvando ? null : _salvarAnamneseNoBanco,
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
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Salvar Ficha',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}