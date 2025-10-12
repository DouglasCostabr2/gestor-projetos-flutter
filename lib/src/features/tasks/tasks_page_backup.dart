import 'package:flutter/material.dart';
import 'widgets/task_history_widget.dart';
import 'widgets/task_assets_section.dart';
import 'widgets/task_briefing_section.dart';
import 'widgets/task_product_link_section.dart';
import 'widgets/task_date_field.dart';
import 'widgets/task_assignee_field.dart';
import 'widgets/task_priority_field.dart';
import 'widgets/task_status_field.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/standard_dialog.dart';
import 'dart:convert';
import 'dart:io';

import '../../state/app_state_scope.dart';
import 'package:gestor_projetos_flutter/services/google_drive_oauth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mime/mime.dart' as mime;
import 'package:gestor_projetos_flutter/widgets/drive_connect_dialog.dart';
import 'package:gestor_projetos_flutter/services/task_files_repository.dart';

import '../../navigation/route_observer.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import 'task_detail_page.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../widgets/table_search_filter_bar.dart';
import '../../../modules/modules.dart';
import '../../../constants/task_status.dart';


class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with RouteAware {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selected = <String>{};

  bool _depsInitialized = false;

  // Busca e filtros
  String _searchQuery = '';
  String _filterType = 'none'; // none, status, priority, project
  String? _filterValue;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Atualizar prioridades baseado no prazo usando o módulo de tarefas
      await tasksModule.updateTasksPriorityByDueDate();

      // Carregar todas as tarefas
      final tasks = await tasksModule.getTasks(offset: 0, limit: 1000);

      if (!mounted) return;
      setState(() {
        _allData = tasks;
        _filteredData = tasks;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_allData);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((task) {
          final title = (task['title'] ?? '').toString().toLowerCase();
          final projectName = (task['projects']?['name'] ?? '').toString().toLowerCase();
          return title.contains(query) || projectName.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterType != 'none' && _filterValue != null && _filterValue!.isNotEmpty) {
        filtered = filtered.where((task) {
          switch (_filterType) {
            case 'status':
              return task['status'] == _filterValue;
            case 'priority':
              return task['priority'] == _filterValue;
            case 'project':
              return task['projects']?['name'] == _filterValue;
            default:
              return true;
          }
        }).toList();
      }

      _filteredData = filtered;
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

    _filteredData.sort((a, b) {
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
        message: 'Deseja realmente excluir ${_selected.length} tarefa(s) selecionada(s)?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selected) {
        await tasksModule.deleteTask(id);
      }

      if (!mounted) return;
      setState(() {
        _allData.removeWhere((e) => _selected.contains(e['id']));
        _filteredData.removeWhere((e) => _selected.contains(e['id']));
        _selected.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarefas excluídas com sucesso')),
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
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredData.length);

    if (startIndex >= _filteredData.length) return [];

    return _filteredData.sublist(startIndex, endIndex);
  }

  // Total de páginas
  int get _totalPages => (_filteredData.length / _itemsPerPage).ceil();

  // Obter comparadores de ordenação
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)?> _getSortComparators() {
    return [
      (a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo((b['title'] ?? '').toString().toLowerCase()),
      (a, b) => (a['projects']?['name'] ?? '').toString().toLowerCase().compareTo((b['projects']?['name'] ?? '').toString().toLowerCase()),
      (a, b) => TaskStatus.values.indexOf(a['status'] ?? TaskStatus.todo).compareTo(TaskStatus.values.indexOf(b['status'] ?? TaskStatus.todo)),
      (a, b) {
        const priorities = ['low', 'medium', 'high', 'urgent'];
        return priorities.indexOf(a['priority'] ?? 'medium').compareTo(priorities.indexOf(b['priority'] ?? 'medium'));
      },
      (a, b) {
        final dateA = a['due_date'] != null ? DateTime.tryParse(a['due_date']) : null;
        final dateB = b['due_date'] != null ? DateTime.tryParse(b['due_date']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      null, // Responsável não ordenável
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
            'Página ${_currentPage + 1} de ${_totalPages > 0 ? _totalPages : 1} • ${_filteredData.length} tarefa(s)',
            style: const TextStyle(color: Colors.white70),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage = _totalPages - 1)
                    : null,
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueProjects() {
    final projects = _allData
        .map((t) => t['projects']?['name'] as String?)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    projects.sort();
    return projects;
  }

  List<String> _getFilterOptions() {
    switch (_filterType) {
      case 'status':
        return ['pending', 'in_progress', 'completed', 'cancelled'];
      case 'priority':
        return ['low', 'medium', 'high', 'urgent'];
      case 'project':
        return _getUniqueProjects();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case 'status':
        return 'Filtrar por status';
      case 'priority':
        return 'Filtrar por prioridade';
      case 'project':
        return 'Filtrar por projeto';
      case 'none':
        return 'Sem filtro';
      default:
        return 'Filtrar';
    }
  }


  Future<void> _openForm({Map<String, dynamic>? initial}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _TaskForm(initial: initial),
    );
    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _duplicate(Map<String, dynamic> task) async {
    try {
      final formData = Map<String, dynamic>.from(task);
      formData.remove('id');
      formData.remove('created_at');
      formData.remove('updated_at');
      formData.remove('projects'); // Remover relação expandida

      if (formData['title'] != null) {
        formData['title'] = '${formData['title']} (Cópia)';
      }

      // Usando o módulo de tarefas para criar
      await tasksModule.createTask(
        projectId: formData['project_id'] ?? '',
        title: formData['title'] ?? '',
        description: formData['description'] ?? '',
        status: formData['status'],
        priority: formData['priority'],
        dueDate: formData['due_date'] != null ? DateTime.parse(formData['due_date']) : null,
        assignedTo: formData['assigned_to'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task duplicada com sucesso')),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar: $e')),
        );
      }
    }
  }

  Future<void> _deleteTaskAndDrive(Map<String, dynamic> t) async {
    final taskTitle = t['title'] as String? ?? 'esta tarefa';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir a tarefa "$taskTitle"?\n\nA pasta no Google Drive também será excluída.',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    final id = t['id'] as String;
    // 1) Delete from DB first usando o módulo de tarefas
    await tasksModule.deleteTask(id);
    if (!mounted) return;

    // OTIMIZAÇÃO: Recarregar dados após deletar
    await _reload();

    // 2) Best-effort delete Drive folder; never block DB deletion
    try {
      final clientName = (t['projects']?['clients']?['name'] ?? 'Cliente').toString();
      final projectName = (t['projects']?['name'] ?? 'Projeto').toString();
      final taskTitle = (t['title'] ?? 'Tarefa').toString();
      final drive = GoogleDriveOAuthService();
      auth.AuthClient? authed;
      try { authed = await drive.getAuthedClient(); } catch (_) {}
      if (authed != null) {
        await drive.deleteTaskFolder(
          client: authed,
          clientName: clientName,
          projectName: projectName,
          taskName: taskTitle,
        );
      } else {
        debugPrint('Drive delete skipped: not authenticated');
      }
    } catch (e) {
      debugPrint('Drive delete failed (ignored): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.isAdminOrGestor || appState.isDesigner;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const Divider(height: 1),

            // Barra de busca e filtros
            TableSearchFilterBar(
              searchHint: 'Buscar tarefa (título ou projeto...)',
              onSearchChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              filterType: _filterType,
              filterTypeLabel: 'Tipo de filtro',
              filterTypeOptions: const [
                FilterOption(value: 'none', label: 'Nenhum'),
                FilterOption(value: 'status', label: 'Status'),
                FilterOption(value: 'priority', label: 'Prioridade'),
                FilterOption(value: 'project', label: 'Projeto'),
              ],
              onFilterTypeChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filterType = value;
                    _filterValue = null;
                  });
                  _applyFilters();
                }
              },
              filterValue: _filterValue,
              filterValueLabel: _getFilterLabel(),
              filterValueOptions: _getFilterOptions(),
              onFilterValueChanged: (value) {
                setState(() => _filterValue = value?.isEmpty == true ? null : value);
                _applyFilters();
              },
              selectedCount: _selected.length,
              bulkActions: canEdit ? [
                BulkAction(
                  icon: Icons.delete,
                  label: 'Excluir selecionados',
                  color: Colors.red,
                  onPressed: _bulkDelete,
                ),
              ] : null,
              actionButton: canEdit ? FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nova Tarefa'),
              ) : null,
            ),

            const SizedBox(height: 16),

            // Área da tabela - ocupa toda altura disponível
            Expanded(
              child: Builder(builder: (context) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro ao carregar tarefas:\n\n${_error!}'),
                    ),
                  );
                }

                if (_filteredData.isEmpty) {
                  return const Center(child: Text('Nenhuma tarefa encontrada'));
                }

                return Column(
                  children: [
                    Expanded(
                      child: ReusableDataTable<Map<String, dynamic>>(
                        items: _getPaginatedData(),
                        selectedIds: _selected,
                        onSelectionChanged: (ids) => setState(() => _selected
                          ..clear()
                          ..addAll(ids)),
                        columns: const [
                          DataTableColumn(label: 'Título', sortable: true),
                          DataTableColumn(label: 'Projeto', sortable: true),
                          DataTableColumn(label: 'Status', sortable: true),
                          DataTableColumn(label: 'Prioridade', sortable: true),
                          DataTableColumn(label: 'Prazo', sortable: true),
                          DataTableColumn(label: 'Responsável'),
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
                          (t) => Text(t['title'] ?? ''),
                          (t) => Text(t['projects']?['name'] ?? '-'),
                          (t) => Text(TaskStatus.getLabel(t['status'] ?? TaskStatus.todo)),
                          (t) {
                            final priority = t['priority'] as String? ?? 'medium';
                            final labels = {'low': 'Baixa', 'medium': 'Média', 'high': 'Alta', 'urgent': 'Urgente'};
                            return Text(labels[priority] ?? priority);
                          },
                          (t) {
                            final dueDate = t['due_date'] != null ? DateTime.tryParse(t['due_date']) : null;
                            if (dueDate == null) return const Text('-');
                            return Text('${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}');
                          },
                          (t) => Text(t['users']?['name'] ?? '-'),
                        ],
                        getId: (t) => t['id'] as String,
                        onRowTap: (t) {
                          // Atualiza a aba atual com os detalhes da tarefa
                          final tabManager = TabManagerScope.maybeOf(context);
                          if (tabManager != null) {
                            final taskId = t['id'].toString();
                            final taskTitle = t['title'] as String? ?? 'Tarefa';
                            final tabId = 'task_$taskId';

                            // Atualiza a aba atual em vez de criar uma nova
                            final currentIndex = tabManager.currentIndex;
                            final currentTab = tabManager.currentTab;
                            final updatedTab = TabItem(
                              id: tabId,
                              title: taskTitle,
                              icon: Icons.task,
                              page: TaskDetailPage(
                                key: ValueKey('task_$taskId'),
                                taskId: taskId,
                              ),
                              canClose: true,
                              selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
                            );
                            tabManager.updateTab(currentIndex, updatedTab);
                          }
                        },
                        actions: [
                          DataTableAction<Map<String, dynamic>>(
                            icon: Icons.edit,
                            label: 'Editar',
                            onPressed: (t) => _openForm(initial: t),
                            showWhen: (t) => canEdit,
                          ),
                          DataTableAction<Map<String, dynamic>>(
                            icon: Icons.content_copy,
                            label: 'Duplicar',
                            onPressed: (t) => _duplicate(t),
                            showWhen: (t) => canEdit,
                          ),
                          DataTableAction<Map<String, dynamic>>(
                            icon: Icons.delete,
                            label: 'Excluir',
                            onPressed: (t) => _deleteTaskAndDrive(t),
                            showWhen: (t) => appState.isAdmin,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('Tarefas', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _TaskForm({this.initial});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _briefingText = '';
  String _briefingJson = '';
  String? _projectId;
  String? _assigneeUserId; // assigned_to
  String _priority = 'medium';
  String _status = 'todo';
  bool _saving = false;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _members = [];
  // Catálogo do Projeto → vínculo de produtos (múltiplos)
  List<Map<String, dynamic>> _linkedProducts = [];
  // Drive/Assets/Briefing support
  final _drive = GoogleDriveOAuthService();
  final _filesRepo = TaskFilesRepository();
  List<PlatformFile> _assetsImages = [];
  List<PlatformFile> _assetsFiles = [];
  List<PlatformFile> _assetsVideos = [];

  // Due date
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _title.text = i['title'] ?? '';
      final d = (i['description'] as String?) ?? '';
      // Try to parse as JSON first (AppFlowy format)
      try {
        final parsed = jsonDecode(d);
        if (parsed is Map) {
          _briefingJson = d;
        } else {
          _briefingText = d;
        }
      } catch (_) {
        // If not JSON, treat as plain text
        _briefingText = d;
      }
      _projectId = i['project_id'] as String?;
      _assigneeUserId = i['assigned_to'] as String?;
      _status = i['status'] ?? 'todo';
      _priority = i['priority'] ?? 'medium';
    }
    _loadProjects();

    if (_projectId != null) {
      _loadMembers(_projectId!);
    }

    // Load existing assets if editing
    if (i != null && i['id'] != null) {
      _loadExistingAssets(i['id'] as String);
    }
  }

  Future<void> _loadExistingAssets(String taskId) async {
    try {
      final files = await _filesRepo.listAssetsByTask(taskId);

      // Note: We can't convert database records back to PlatformFile with bytes
      // because we'd need to download from Google Drive.
      // For now, we'll just show a message that existing assets are in Drive.

      debugPrint('Found ${files.length} existing assets for task $taskId');
      // Files are already in Google Drive, no need to re-upload
    } catch (e) {
      debugPrint('Error loading existing assets: $e');
    }
  }

  Future<void> _loadProjects() async {
    // Usando o módulo de projetos
    final res = await projectsModule.getProjects();
    final list = res;
    // Deduplicate by id to avoid duplicate DropdownMenuItem values
    final seen = <String>{};
    final dedup = list.where((p) {
      final id = p['id'] as String?;
      if (id == null || seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList();
    setState(() => _projects = dedup);
  }

  Future<void> _loadMembers(String projectId) async {
    try {
      // Usando o módulo de projetos para buscar membros
      final res = await projectsModule.getProjectMembers(projectId);
      final all = res;
      var filtered = all.where((m) {
        final role = (m['profiles']?['role'] as String?)?.toLowerCase();
        return role == 'admin' || role == 'gestor' || role == 'funcionario';
      }).toList();
      // Fallback: if no members found, list all admin/funcionarios from profiles
      if (filtered.isEmpty) {
        // Usando o módulo de usuários
        final prof = await usersModule.getAllProfiles();
        filtered = List<Map<String, dynamic>>.from(prof).map((p) => {
          'user_id': p['id'],
          'profiles': p,
        }).toList();
      }
      if (!mounted) return;
      setState(() => _members = filtered);
    } catch (e) {
      debugPrint('Erro ao carregar membros do projeto: $e');
      if (!mounted) return;
      setState(() => _members = []);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return; // reentrancy guard
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // DEBUG: Verificar usuário atual usando o módulo de autenticação
    final currentUser = authModule.currentUser;
    debugPrint('=== SAVE TASK DEBUG ===');
    debugPrint('Current User ID: ${currentUser?.id}');
    debugPrint('Current User Email: ${currentUser?.email}');
    debugPrint('Project ID: $_projectId');
    debugPrint('Linked Products: ${_linkedProducts.length}');

    final base = {
      'title': _title.text.trim(),
      'description': _briefingJson.isNotEmpty ? _briefingJson : (_briefingText.isNotEmpty ? _briefingText : null),
      'project_id': _projectId,
      'assigned_to': _assigneeUserId,
      'status': _status,
      'priority': _priority,
      'due_date': _dueDate == null ? null : DateUtils.dateOnly(_dueDate!).toIso8601String(),
    };
    final messenger = ScaffoldMessenger.of(context);
    // use local context directly with mounted checks; avoid caching across async gaps
    try {
      Map<String, dynamic>? taskRow;
      if (widget.initial == null) {
        // Criar nova tarefa usando o módulo
        taskRow = await tasksModule.createTask(
          projectId: base['project_id'] ?? '',
          title: base['title'] ?? '',
          description: base['description'],
          status: base['status'] ?? 'todo',
          priority: base['priority'] ?? 'medium',
          dueDate: base['due_date'] != null ? DateTime.parse(base['due_date'] as String) : null,
          assignedTo: base['assigned_to'],
        );
      } else {
        final beforeStatus = (widget.initial!['status'] as String?)?.toLowerCase();
        // Atualizar tarefa existente usando o módulo
        await tasksModule.updateTask(
          taskId: widget.initial!['id'],
          title: base['title'],
          description: base['description'],
          assignedTo: base['assigned_to'],
          status: base['status'],
          priority: base['priority'],
          dueDate: base['due_date'] != null ? DateTime.parse(base['due_date'] as String) : null,
        );
        taskRow = await tasksModule.getTaskById(widget.initial!['id']);
        taskRow ??= {'id': widget.initial!['id'], 'title': base['title']};

        final afterStatus = (_status).toLowerCase();
        final turnedCompleted = beforeStatus != 'completed' && afterStatus == 'completed';
        final leftCompleted = beforeStatus == 'completed' && afterStatus != 'completed';
        if (turnedCompleted || leftCompleted) {
          try {
            final clientName = (taskRow['projects']?['clients']?['name'] ?? 'Cliente').toString();
            final projectName = (taskRow['projects']?['name'] ?? 'Projeto').toString();
            final taskTitle = (taskRow['title'] ?? 'Tarefa').toString();

            final drive = GoogleDriveOAuthService();
            final authed = await drive.getAuthedClient();
            if (turnedCompleted) {
              await drive.addCompletedBadgeToTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
              );
            } else if (leftCompleted) {
              await drive.removeCompletedBadgeFromTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
              );
            }
          } catch (e) {
            debugPrint('Falha ao atualizar ✅ na pasta da tarefa: $e');
          }
        }
      }

      // Snapshot current selections to avoid duplicate uploads on accidental re-entry
      final assetsImages = List<PlatformFile>.from(_assetsImages);
      final assetsFiles = List<PlatformFile>.from(_assetsFiles);
      final assetsVideos = List<PlatformFile>.from(_assetsVideos);
      // Clear originals; if _save() is triggered again, lists are empty and won't re-upload
      setState(() {
        _assetsImages.clear();
        _assetsFiles.clear();
        _assetsVideos.clear();
      });

      // Upload Assets (se houver)
      if (assetsImages.isNotEmpty || assetsFiles.isNotEmpty || assetsVideos.isNotEmpty) {
        try {
          auth.AuthClient? client;
          try {
            client = await _drive.getAuthedClient();
          } on ConsentRequired catch (_) {
            if (!mounted) return;
            final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
            if (ok == true) client = await _drive.getAuthedClient();
          }
          if (client != null) {
            final taskId = taskRow['id'] as String;
            final clientName = (taskRow['projects']?['clients']?['name'] ?? 'Cliente').toString();
            final projectName = (taskRow['projects']?['name'] ?? 'Projeto').toString();
            final taskTitle = (taskRow['title'] ?? 'Tarefa').toString();

            Future<void> uploadList(List<PlatformFile> list) async {
              for (final f in list) {
                final name = f.name;
                final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
                if (bytes == null) continue;
                final mt = mime.lookupMimeType(name);
                final up = await _drive.uploadToTaskSubfolder(
                  client: client!,
                  clientName: clientName,
                  projectName: projectName,
                  taskName: taskTitle,
                  subfolderName: 'Assets',
                  filename: name,
                  bytes: bytes,
                  mimeType: mt,
                );
                await _filesRepo.saveFile(
                  taskId: taskId,
                  filename: name,
                  sizeBytes: bytes.length,
                  mimeType: mt,
                  driveFileId: up.id,
                  driveFileUrl: up.publicViewUrl,
                  category: 'assets',
                );
              }
            }

            await uploadList(assetsImages);
            await uploadList(assetsFiles);
            await uploadList(assetsVideos);
          }
        } catch (e) {
          debugPrint('Falha ao enviar assets: $e');
        }
      }
      // Note: AppFlowy Editor handles image uploads internally
      // The briefing JSON is already saved in the 'description' field above

      /* OLD QUILL IMAGE PROCESSING - Not needed with AppFlowy
      try {
        final List<Map<String, dynamic>> ops = List<Map<String, dynamic>>.from(_briefingCtrl.document.toDelta().toJson());
        final usedBriefingNames = <String>{};
        String uniqueBriefingName(String name) {
          var candidate = name;
          int i = 1;
          while (usedBriefingNames.contains(candidate)) {
            final dot = candidate.lastIndexOf('.');
            final base = dot >= 0 ? candidate.substring(0, dot) : candidate;
            final ext = dot >= 0 ? candidate.substring(dot) : '';
            candidate = "$base ($i)$ext";
            i++;
          }
          usedBriefingNames.add(candidate);
          return candidate;
        }

        // Tentar autenticar Drive sob demanda (com consent flow)
        Future<auth.AuthClient?> ensureClient() async {
          try {
            return await _drive.getAuthedClient();
          } on ConsentRequired catch (_) {
            if (!mounted) return null;
            final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
            if (ok == true) {
              try { return await _drive.getAuthedClient(); } catch (_) { return null; }
            }
            return null;
          }
        }

        auth.AuthClient? client;
        for (var i = 0; i < ops.length; i++) {
          final op = ops[i];
          final insert = op['insert'];
          if (insert is Map && insert['image'] is String) {
            final src = insert['image'] as String;
            List<int>? bytes;
            String? mimeType;

            if (src.startsWith('data:')) {
              final comma = src.indexOf(',');
              if (comma > 0) {
                final header = src.substring(5, comma); // e.g. image/png;base64
                final b64 = src.substring(comma + 1);
                bytes = base64Decode(b64);
                mimeType = header.split(';').first;
              }
            } else if (src.startsWith('file://') || _isAbsolutePath(src)) {
              final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
              final file = File(filePath);
              if (await file.exists()) {
                bytes = await file.readAsBytes();
                mimeType = mime.lookupMimeType(filePath) ?? 'image/png';
              }
            }

            if (bytes != null && mimeType != null) {
              String ext;
              switch (mimeType) {
                case 'image/jpeg': ext = 'jpg'; break;
                case 'image/png': ext = 'png'; break;
                case 'image/gif': ext = 'gif'; break;
                case 'image/webp': ext = 'webp'; break;
                default: ext = 'bin';
              }

              client ??= await ensureClient();
              if (client == null) break;

              final taskId = taskRow['id'] as String;
              final clientName = (taskRow['projects']?['clients']?['name'] ?? 'Cliente').toString();
              final projectName = (taskRow['projects']?['name'] ?? 'Projeto').toString();
              final taskTitle = (taskRow['title'] ?? 'Tarefa').toString();

              // Determine original filename for Briefing images
              String originalName;
              if (src.startsWith('file://') || _isAbsolutePath(src)) {
                final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
                originalName = filePath.split(RegExp(r'[\\/]')).last;
                // If temp name contains original after "__", extract it
                if (originalName.contains('__')) {
                  originalName = originalName.split('__').last;
                }
                // Ensure it has an extension
                if (!originalName.contains('.')) {
                  originalName = '$originalName.$ext';
                }
                if (!originalName.toLowerCase().startsWith('briefing_')) {
                  originalName = 'Briefing_$originalName';
                } else {
                  // Normalize first letter to uppercase B
                  originalName = 'Briefing_${originalName.substring('briefing_'.length)}';
                }
              } else {
                originalName = 'Briefing_image.$ext';
              }
              final filename = uniqueBriefingName(originalName);

              final up = await _drive.uploadToTaskSubfolder(
                client: client,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
                subfolderName: 'Briefing',
                filename: filename,
                bytes: bytes,
                mimeType: mimeType,
              );

              await _filesRepo.saveFile(
                taskId: taskId,
                filename: filename,
                sizeBytes: bytes.length,
                mimeType: mimeType,
                driveFileId: up.id,
                driveFileUrl: up.publicViewUrl,
                category: 'briefing',
              );

              op['insert'] = { 'image': up.publicViewUrl };
              ops[i] = op;
            }
          }
        }

        // Persistir JSON do Delta (mesmo sem imagens, guarda formatação)
        final descJson = jsonEncode(ops);
        await Supabase.instance.client
            .from('tasks')
            .update({'description': descJson})
            .eq('id', taskRow['id']);
      } catch (e) {
        debugPrint('Falha ao processar briefing/delta: $e');
      }
      */

      // Save linked products to task_products table
      try {
        final taskId = taskRow['id'] as String;
        final client = Supabase.instance.client;

        debugPrint('=== SAVING LINKED PRODUCTS ===');
        debugPrint('Task ID: $taskId');
        debugPrint('Products to link: ${_linkedProducts.length}');
        debugPrint('Current User: ${client.auth.currentUser?.id}');
        debugPrint('Current User Email: ${client.auth.currentUser?.email}');

        // Delete existing links for this task
        debugPrint('Deleting existing links...');
        await client.from('task_products').delete().eq('task_id', taskId);
        debugPrint('Existing links deleted');

        // Insert new links
        if (_linkedProducts.isNotEmpty) {
          final inserts = _linkedProducts.map((p) => {
            'task_id': taskId,
            'product_id': p['productId'],
            'package_id': p['packageId'],
            'created_by': client.auth.currentUser!.id,
          }).toList();

          debugPrint('Inserting ${inserts.length} products...');
          debugPrint('Inserts: $inserts');

          await client.from('task_products').insert(inserts);
          debugPrint('Products linked successfully!');
        }
      } catch (e) {
        debugPrint('Falha ao salvar produtos vinculados: $e');
      }

      // Clear selections to avoid duplicates if this widget remains mounted
      if (mounted) {
        setState(() {
          _assetsImages.clear();
          _assetsFiles.clear();
          _assetsVideos.clear();

        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('Erro ao salvar tarefa: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Stack(children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.initial == null ? 'Nova Tarefa' : 'Editar Tarefa', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                // Projeto (no topo)
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('project:${_projectId ?? ''}'),
                  isExpanded: true,
                  initialValue: _projects.any((p) => p['id'] == _projectId) ? _projectId : null,
                  items: _projects
                      .map((p) => DropdownMenuItem<String>(
                            value: p['id'] as String,
                            child: Text(p['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _projectId = v;
                    if (v != null) {
                      _loadMembers(v);
                    }
                  }),
                  validator: (v) => v == null ? 'Selecione um projeto' : null,
                  decoration: const InputDecoration(labelText: 'Projeto *'),
                ),
                const SizedBox(height: 12),

                // MOVIDO: Título e Briefing para o topo
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null,
                ),
                const SizedBox(height: 12),

                // Prazo e Responsável lado a lado
                Row(
                  children: [
                    Expanded(
                      child: TaskDateField(
                        dueDate: _dueDate,
                        onDateChanged: (date) {
                          setState(() => _dueDate = date);
                        },
                        enabled: !_saving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TaskAssigneeField(
                        assigneeUserId: _assigneeUserId,
                        members: _members,
                        onAssigneeChanged: (userId) {
                          setState(() => _assigneeUserId = userId);
                        },
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TaskProductLinkSection(
                  projectId: _projectId,
                  taskId: widget.initial?['id'] as String?,
                  onLinkedProductsChanged: (products) {
                    setState(() => _linkedProducts = products);
                  },
                  enabled: !_saving,
                ),

                const SizedBox(height: 16),
                // Briefing após Produto
                TaskBriefingSection(
                  initialJson: _briefingJson.isNotEmpty ? _briefingJson : null,
                  initialText: _briefingJson.isEmpty ? _briefingText : null,
                  onChanged: (text) {
                    setState(() => _briefingText = text);
                  },
                  onJsonChanged: (json) {
                    setState(() => _briefingJson = json);
                  },
                  enabled: !_saving,
                ),
                const SizedBox(height: 16),


                // Assets
                TaskAssetsSection(
                  taskId: widget.initial?['id'] as String?,
                  assetsImages: _assetsImages,
                  assetsFiles: _assetsFiles,
                  assetsVideos: _assetsVideos,
                  onAssetsChanged: (images, files, videos) {
                    setState(() {
                      _assetsImages = images;
                      _assetsFiles = files;
                      _assetsVideos = videos;
                    });
                  },
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TaskStatusField(
                        status: _status,
                        onStatusChanged: (status) {
                          setState(() => _status = status);
                        },
                        enabled: !_saving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TaskPriorityField(
                        priority: _priority,
                        onPriorityChanged: (priority) {
                          setState(() => _priority = priority);
                        },
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Histórico de Alterações
                if (widget.initial != null && widget.initial!['id'] != null) ...[
                  ExpansionTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Histórico de Alterações'),
                    initiallyExpanded: false,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: TaskHistoryWidget(taskId: widget.initial!['id'] as String),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const SizedBox(height: 84)
              ],
            ),
          ),
        )),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    // Match the dialog surface including surface tint/elevation overlay
                    color: ElevationOverlay.applySurfaceTint(
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceTint,
                      Theme.of(context).dialogTheme.elevation ?? 6.0,
                    ),
                    border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: Offset(0, -2))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),


                        const SizedBox(width: 8),
                        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvando...' : 'Salvar')),
                      ],
                    ),
                  ),
                ),
              ),
            ]),

      ),
    ),

    );
  }
}

