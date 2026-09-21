import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServicosPage extends StatefulWidget {
  const ServicosPage({super.key});

  @override
  State<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends State<ServicosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _nomeProfissional = 'Carregando...';

  // Controllers para o formulário de serviço
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();
  final TextEditingController _duracaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscarNomeProfissional();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  // Busca dinâmica do profissional logado
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

  // Função para salvar o serviço no Supabase
  Future<void> _salvarServico() async {
    final nome = _nomeController.text.trim();
    final precoTexto = _precoController.text.trim().replaceAll(',', '.');
    final duracao = _duracaoController.text.trim();

    if (nome.isEmpty || precoTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha o nome e o preço.')),
      );
      return;
    }

    final double? preco = double.tryParse(precoTexto);
    if (preco == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um preço válido.')),
      );
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('servicos').insert({
        'id_usuario': user.id, // Garante o isolamento por usuário
        'nome': nome,
        'preco': preco,
        'duracao': duracao.isNotEmpty ? duracao : null,
      });

      if (mounted) {
        Navigator.pop(context);
        _nomeController.clear();
        _precoController.clear();
        _duracaoController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço criado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar serviço: $e')),
        );
      }
    }
  }

  // Função para atualizar o serviço existente no Supabase
  Future<void> _atualizarServico(dynamic id) async {
    final nome = _nomeController.text.trim();
    final precoTexto = _precoController.text.trim().replaceAll(',', '.');
    final duracao = _duracaoController.text.trim();

    if (nome.isEmpty || precoTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha o nome e o preço.')),
      );
      return;
    }

    final double? preco = double.tryParse(precoTexto);
    if (preco == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um preço válido.')),
      );
      return;
    }

    try {
      await _supabase.from('servicos').update({
        'nome': nome,
        'preco': preco,
        'duracao': duracao.isNotEmpty ? duracao : null,
      }).eq('id', id);

      if (mounted) {
        Navigator.pop(context);
        _nomeController.clear();
        _precoController.clear();
        _duracaoController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar serviço: $e')),
        );
      }
    }
  }

  // Função para deletar o serviço do Supabase
  Future<void> _deletarServico(dynamic id) async {
    try {
      await _supabase
        .from('servicos')
        .update({'ativo': false})
        .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço excluído com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir serviço: $e')),
        );
      }
    }
  }

  // Modal para Criar Serviço
  void _abrirModalCriarServico() {
    _nomeController.clear();
    _precoController.clear();
    _duracaoController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Novo Serviço',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Serviço *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço (R\$) *',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duracaoController,
                      decoration: const InputDecoration(
                        labelText: 'Duração (Opcional)',
                        hintText: 'Ex: 50 min',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarServico,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5993F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Salvar Serviço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal para Editar Serviço
  void _abrirModalEditarServico(Map<String, dynamic> servico) {
    _nomeController.text = servico['nome'] ?? '';
    _precoController.text = servico['preco']?.toString() ?? '';
    _duracaoController.text = servico['duracao'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Editar Serviço',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Serviço *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço (R\$) *',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duracaoController,
                      decoration: const InputDecoration(
                        labelText: 'Duração (Opcional)',
                        hintText: 'Ex: 50 min',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _atualizarServico(servico['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5993F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Atualizar Serviço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _nomeController.clear();
      _precoController.clear();
      _duracaoController.clear();
    });
  }

  // Modal Alerta para Confirmar Exclusão
  void _abrirModalDeletarServico(Map<String, dynamic> servico) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Excluir Serviço', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Tem certeza que deseja excluir o serviço "${servico['nome']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deletarServico(servico['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    // Stream filtrada especificamente para o usuário logado
    final Stream<List<Map<String, dynamic>>> streamServicos = user == null
        ? const Stream.empty()
        : _supabase
            .from('servicos')
            .stream(primaryKey: ['id'])
            .eq('id_usuario', user.id)
            .order('nome')
            .map((lista) => lista.where((s) => s['ativo'] == true).toList());

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
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Column(
            children: [
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.reply, size: 32, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _abrirModalCriarServico,
                label: const Text(
                  'Adicionar serviço',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE4C47A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.black54),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.black, size: 28),
              ),
              const SizedBox(height: 24),
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
                        stream: streamServicos,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFFC5993F)),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Erro ao carregar serviços: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          final listaServicos = snapshot.data ?? [];

                          if (listaServicos.isEmpty) {
                            return const Center(
                              child: Text(
                                'Nenhum serviço cadastrado.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12.0),
                            itemCount: listaServicos.length,
                            itemBuilder: (context, index) {
                              final servico = listaServicos[index];
                              final double preco = double.tryParse(servico['preco'].toString()) ?? 0.0;
                              final String duracao = servico['duracao']?.toString() ?? 'Sem tempo definido';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9CC9BC),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              servico['nome'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Duração: $duracao',
                                              style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: 26,
                                        icon: const Icon(Icons.edit, color: Colors.black54),
                                        onPressed: () => _abrirModalEditarServico(servico),
                                      ),
                                      IconButton(
                                        iconSize: 26,
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _abrirModalDeletarServico(servico),
                                      ),
                                    ],
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