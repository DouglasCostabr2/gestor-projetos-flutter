import 'package:flutter/material.dart';
import 'icon_only_button.dart';

/// Exemplos de uso do IconOnlyButton
///
/// Este arquivo demonstra os diferentes casos de uso do componente IconOnlyButton.
class IconOnlyButtonExamples extends StatefulWidget {
  const IconOnlyButtonExamples({super.key});

  @override
  State<IconOnlyButtonExamples> createState() => _IconOnlyButtonExamplesState();
}

class _IconOnlyButtonExamplesState extends State<IconOnlyButtonExamples> {
  bool _loading = false;

  void _simulateLoading() {
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IconOnlyButton Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exemplo 1: Botões em uma toolbar
            _buildSection(
              'Toolbar Actions',
              Row(
                children: [
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.edit,
                    tooltip: 'Editar',
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.delete,
                    tooltip: 'Excluir',
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.share,
                    tooltip: 'Compartilhar',
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.more_vert,
                    tooltip: 'Mais opções',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Exemplo 2: Variantes
            _buildSection(
              'Variantes',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    children: [
                      IconOnlyButton(
                        onPressed: () {},
                        icon: Icons.home,
                        tooltip: 'Standard',
                        variant: IconButtonVariant.standard,
                      ),
                      const SizedBox(height: 4),
                      const Text('Standard', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      IconOnlyButton(
                        onPressed: () {},
                        icon: Icons.home,
                        tooltip: 'Filled',
                        variant: IconButtonVariant.filled,
                      ),
                      const SizedBox(height: 4),
                      const Text('Filled', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      IconOnlyButton(
                        onPressed: () {},
                        icon: Icons.home,
                        tooltip: 'Tonal',
                        variant: IconButtonVariant.tonal,
                      ),
                      const SizedBox(height: 4),
                      const Text('Tonal', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      IconOnlyButton(
                        onPressed: () {},
                        icon: Icons.home,
                        tooltip: 'Outlined',
                        variant: IconButtonVariant.outlined,
                      ),
                      const SizedBox(height: 4),
                      const Text('Outlined', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Exemplo 3: Loading state
            _buildSection(
              'Loading State',
              Row(
                children: [
                  IconOnlyButton(
                    onPressed: _loading ? null : _simulateLoading,
                    icon: Icons.refresh,
                    tooltip: 'Recarregar',
                    isLoading: _loading,
                  ),
                  const SizedBox(width: 16),
                  IconOnlyButton(
                    onPressed: _loading ? null : _simulateLoading,
                    icon: Icons.refresh,
                    tooltip: 'Recarregar (Filled)',
                    variant: IconButtonVariant.filled,
                    isLoading: _loading,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Exemplo 4: Tamanhos diferentes
            _buildSection(
              'Tamanhos Customizados',
              Row(
                children: [
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.star,
                    tooltip: 'Pequeno',
                    iconSize: 16,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.star,
                    tooltip: 'Médio',
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.star,
                    tooltip: 'Grande',
                    iconSize: 28,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Exemplo 5: Uso em tabela
            _buildSection(
              'Ações em Tabela',
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FixedColumnWidth(100),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    _buildTableRow('Projeto A', 'Ativo'),
                    _buildTableRow('Projeto B', 'Pausado'),
                    _buildTableRow('Projeto C', 'Concluído'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Exemplo 6: Cores customizadas
            _buildSection(
              'Cores Customizadas',
              Row(
                children: [
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.favorite,
                    tooltip: 'Favoritar',
                    iconColor: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.check_circle,
                    tooltip: 'Aprovar',
                    iconColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: () {},
                    icon: Icons.warning,
                    tooltip: 'Aviso',
                    iconColor: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  TableRow _buildTableRow(String name, String status) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(name),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(status),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconOnlyButton(
                onPressed: () {},
                icon: Icons.edit,
                tooltip: 'Editar',
                iconSize: 18,
              ),
              const SizedBox(width: 4),
              IconOnlyButton(
                onPressed: () {},
                icon: Icons.delete,
                tooltip: 'Excluir',
                iconSize: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

