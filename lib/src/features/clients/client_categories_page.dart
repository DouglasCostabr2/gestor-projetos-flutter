import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../widgets/table_search_filter_bar.dart';
import '../../../widgets/standard_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

class ClientCategoriesPage extends StatefulWidget {
  const ClientCategoriesPage({super.key});

  @override
  State<ClientCategoriesPage> createState() => _ClientCategoriesPageState();
}

class _ClientCategoriesPageState extends State<ClientCategoriesPage> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _filteredCategories = [];
  bool _loading = true;
  Set<String> _selected = {};

  // Busca
  String _searchQuery = '';

  // Paginação
  int _currentPage = 0;
  final int _itemsPerPage = 5;

  // Ordenação
  int? _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('client_categories')
          .select('*')
          .order('name');
      
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_categories);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((category) {
          final name = (category['name'] ?? '').toString().toLowerCase();
          final description = (category['description'] ?? '').toString().toLowerCase();
          return name.contains(query) || description.contains(query);
        }).toList();
      }

      _filteredCategories = filtered;
      _applySorting();
      _currentPage = 0; // Reset para primeira página
    });
  }

  void _applySorting() {
    if (_sortColumnIndex == null) return;

    final comparators = _getSortComparators();
    if (_sortColumnIndex! >= comparators.length) return;

    final comparator = comparators[_sortColumnIndex!];
    if (comparator == null) return;

    _filteredCategories.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscending ? result : -result;
    });
  }

  // Função para exclusão em lote
  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir ${_selected.length} categoria(s) selecionada(s)?\n\nClientes associados a elas não serão excluídos, mas perderão a referência.',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selected) {
        await Supabase.instance.client
            .from('client_categories')
            .delete()
            .eq('id', id);
      }

      if (!mounted) return;
      setState(() {
        _categories.removeWhere((e) => _selected.contains(e['id']));
        _filteredCategories.removeWhere((e) => _selected.contains(e['id']));
        _selected.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categorias excluídas com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  // Obter itens da página atual
  List<Map<String, dynamic>> _getPaginatedData() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredCategories.length);

    if (startIndex >= _filteredCategories.length) return [];

    return _filteredCategories.sublist(startIndex, endIndex);
  }

  // Total de páginas
  int get _totalPages => (_filteredCategories.length / _itemsPerPage).ceil();

  // Obter comparadores de ordenação
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)?> _getSortComparators() {
    return [
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()),
      (a, b) => (a['description'] ?? '').toString().toLowerCase().compareTo((b['description'] ?? '').toString().toLowerCase()),
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
    ];
  }

  // Widget de controles de paginação
  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF3E3E3E)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Página ${_currentPage + 1} de ${_totalPages > 0 ? _totalPages : 1} • ${_filteredCategories.length} categoria(s)',
            style: const TextStyle(color: Colors.white70),
          ),
          Row(
            children: [
              IconOnlyButton(
                icon: Icons.first_page,
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
                iconColor: Colors.white,
                tooltip: 'Primeira página',
              ),
              IconOnlyButton(
                icon: Icons.chevron_left,
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                iconColor: Colors.white,
                tooltip: 'Página anterior',
              ),
              IconOnlyButton(
                icon: Icons.chevron_right,
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                iconColor: Colors.white,
                tooltip: 'Próxima página',
              ),
              IconOnlyButton(
                icon: Icons.last_page,
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage = _totalPages - 1)
                    : null,
                iconColor: Colors.white,
                tooltip: 'Última página',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? initial}) async {
    final nameController = TextEditingController(text: initial?['name']);
    final descController = TextEditingController(text: initial?['description']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryFormDialog(
        initial: initial,
        nameController: nameController,
        descController: descController,
      ),
    );

    if (result == true) {
      _reload();
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Excluir Categoria',
        message: 'Tem certeza que deseja excluir esta categoria?\n\nClientes associados a ela não serão excluídos, mas perderão a referência.',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('client_categories')
          .delete()
          .eq('id', id);
      
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria excluída com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.isAdminOrGestor;
    final canDelete = appState.isAdmin;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Categorias de Clientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_categories.length} ${_categories.length == 1 ? 'categoria' : 'categorias'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Barra de busca
        TableSearchFilterBar(
          searchHint: 'Buscar categoria (nome ou descrição...)',
          onSearchChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
          showFilters: false, // Sem filtros adicionais para categorias
          selectedCount: _selected.length,
          bulkActions: canDelete ? [
            BulkAction(
              icon: Icons.delete,
              label: 'Excluir selecionados',
              color: Colors.red,
              onPressed: _bulkDelete,
            ),
          ] : null,
          actionButton: canEdit ? FilledButton.icon(
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Nova Categoria'),
          ) : null,
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Área da tabela com altura fixa
                  SizedBox(
                    height: 600,
                    child: Builder(builder: (context) {
                      if (_loading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_filteredCategories.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Nenhuma categoria cadastrada'
                                    : 'Nenhuma categoria encontrada',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ReusableDataTable<Map<String, dynamic>>(
                              items: _getPaginatedData(),
                              selectedIds: _selected,
                              onSelectionChanged: (ids) => setState(() => _selected = ids),
                              columns: const [
                                DataTableColumn(label: 'Nome', flex: 2, sortable: true),
                                DataTableColumn(label: 'Descrição', flex: 3, sortable: true),
                                DataTableColumn(label: 'Criado em', sortable: true),
                              ],
                              sortComparators: _getSortComparators(),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                  _applySorting();
                                  _currentPage = 0;
                                });
                              },
                              externalSortColumnIndex: _sortColumnIndex,
                              externalSortAscending: _sortAscending,
                              cellBuilders: [
                                (cat) => Text(
                                  cat['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                (cat) => Text(cat['description'] ?? '-'),
                                (cat) {
                                  final createdAt = cat['created_at'];
                                  if (createdAt == null) return const Text('-');
                                  try {
                                    final date = DateTime.parse(createdAt);
                                    return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
                                  } catch (e) {
                                    return const Text('-');
                                  }
                                },
                              ],
                              getId: (cat) => cat['id'] as String,
                              actions: [
                                if (canEdit)
                                  DataTableAction(
                                    icon: Icons.edit,
                                    label: 'Editar',
                                    onPressed: (cat) => _showCategoryDialog(initial: cat),
                                  ),
                                if (canEdit)
                                  DataTableAction(
                                    icon: Icons.content_copy,
                                    label: 'Duplicar',
                                    onPressed: (cat) async {
                                      try {
                                        final formData = Map<String, dynamic>.from(cat);
                                        formData.remove('id');
                                        formData.remove('created_at');
                                        formData.remove('updated_at');
                                        if (formData['name'] != null) {
                                          formData['name'] = '${formData['name']} (Cópia)';
                                        }

                                        await Supabase.instance.client.from('client_categories').insert(formData);

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Categoria duplicada com sucesso')),
                                        );
                                        _reload();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Erro ao duplicar: $e')),
                                        );
                                      }
                                    },
                                  ),
                                if (canDelete)
                                  DataTableAction(
                                    icon: Icons.delete,
                                    label: 'Excluir',
                                    onPressed: (cat) => _delete(cat['id'] as String),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPaginationControls(),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FORMULÁRIO DE CATEGORIA
// ============================================================================

class _CategoryFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final TextEditingController nameController;
  final TextEditingController descController;

  const _CategoryFormDialog({
    this.initial,
    required this.nameController,
    required this.descController,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  bool _saving = false;

  Future<void> _save() async {
    if (widget.nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final data = {
        'name': widget.nameController.text.trim(),
        'description': widget.descController.text.trim().isEmpty
            ? null
            : widget.descController.text.trim(),
      };

      if (widget.initial == null) {
        await Supabase.instance.client
            .from('client_categories')
            .insert(data);
      } else {
        await Supabase.instance.client
            .from('client_categories')
            .update(data)
            .eq('id', widget.initial!['id']);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return StandardDialog(
      title: isEdit ? 'Editar Categoria' : 'Nova Categoria',
      width: StandardDialog.widthSmall,
      height: StandardDialog.heightSmall,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando...' : (isEdit ? 'Salvar' : 'Criar')),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.nameController,
            decoration: const InputDecoration(
              labelText: 'Nome *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.descController,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: !_saving,
          ),
        ],
      ),
    );
  }
}
