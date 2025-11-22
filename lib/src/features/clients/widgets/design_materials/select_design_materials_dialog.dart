import 'package:flutter/material.dart';
import '../../../../../services/design_materials_repository.dart';
import '../../../../../ui/atoms/badges/simple_badge.dart';
import '../../../../../ui/organisms/tables/table_search_filter_bar.dart';

/// Dialog para selecionar arquivos do Design Materials
///
/// Permite selecionar arquivos de QUALQUER empresa/cliente da organização
/// para evitar duplicação de arquivos.
///
/// Retorna uma lista de arquivos selecionados com suas informações:
/// - filename
/// - drive_file_id
/// - drive_file_url
/// - mime_type
/// - file_size_bytes
class SelectDesignMaterialsDialog extends StatefulWidget {
  final String? companyId; // Opcional - se fornecido, inicia nesta empresa
  final String? companyName;

  const SelectDesignMaterialsDialog({
    super.key,
    this.companyId,
    this.companyName,
  });

  @override
  State<SelectDesignMaterialsDialog> createState() => _SelectDesignMaterialsDialogState();
}

class _SelectDesignMaterialsDialogState extends State<SelectDesignMaterialsDialog> {
  final _repository = DesignMaterialsRepository();

  // Navegação hierárquica: Clientes → Empresas → Pastas → Arquivos
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _tags = []; // Tags disponíveis

  // Cache de dados por empresa (para evitar mostrar dados de outra empresa)
  final Map<String, List<Map<String, dynamic>>> _foldersByCompany = {};
  final Map<String, List<Map<String, dynamic>>> _filesByCompany = {};

  // Getters para acessar dados da empresa selecionada
  List<Map<String, dynamic>> get _files => _selectedCompanyId != null
      ? (_filesByCompany[_selectedCompanyId!] ?? [])
      : [];

  String? _selectedClientId;
  String? _selectedCompanyId;
  String? _selectedFolderId;
  final Set<String> _selectedFileIds = {};

  // ValueNotifiers para atualizar áreas independentemente
  late final ValueNotifier<int> _filesAreaNotifier;
  late final ValueNotifier<int> _navigationAreaNotifier;
  late final ValueNotifier<bool> _loadingNotifier;

  // Controllers
  final TextEditingController _navigationSearchController = TextEditingController();

  // Filtros (mesma lógica da aba Design Materials)
  String _searchQuery = ''; // Pesquisa de arquivos
  String _navigationSearchQuery = ''; // Pesquisa de clientes/empresas
  String _filterType = 'none';
  String? _filterValue;

  // Chave única para forçar rebuild da árvore de navegação
  int _navigationTreeKey = 0;

  @override
  void initState() {
    super.initState();
    _filesAreaNotifier = ValueNotifier<int>(0);
    _navigationAreaNotifier = ValueNotifier<int>(0);
    _loadingNotifier = ValueNotifier<bool>(true);
    _loadClients();
  }

  @override
  void dispose() {
    _filesAreaNotifier.dispose();
    _navigationAreaNotifier.dispose();
    _loadingNotifier.dispose();
    _navigationSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    _loadingNotifier.value = true;

    try {
      final clients = await _repository.getClientsWithCompanies();
      final tags = await _repository.getTags();

      if (mounted) {
        _clients = clients;
        _tags = tags;
        _loadingNotifier.value = false;
        _navigationAreaNotifier.value++;

        // Se foi fornecido um companyId inicial, selecionar automaticamente
        if (widget.companyId != null) {
          _selectInitialCompany(widget.companyId!);
        }
      }
    } catch (e) {
      if (mounted) {
        _loadingNotifier.value = false;
      }
    }
  }

  void _selectInitialCompany(String companyId) {
    // Encontrar o cliente e empresa correspondentes
    for (final client in _clients) {
      final companies = client['companies'] as List<dynamic>?;
      if (companies != null) {
        for (final company in companies) {
          if (company['id'] == companyId) {
            _selectedClientId = client['id'] as String;
            _selectedCompanyId = companyId;
            _loadCompanyData(companyId);
            return;
          }
        }
      }
    }
  }

  Future<void> _loadCompanyData(String companyId) async {

    // Não mostra loading ao trocar de empresa, apenas atualiza os arquivos
    try {
      final folders = await _repository.getFolders(companyId);
      final files = await _repository.getFiles(companyId);


      if (mounted) {
        // Armazena dados no cache por empresa
        _foldersByCompany[companyId] = folders;
        _filesByCompany[companyId] = files;
        _selectedCompanyId = companyId;

        // Atualiza área de arquivos imediatamente
        _filesAreaNotifier.value++;

        // Aguarda um frame para permitir animação de colapso, depois atualiza navegação
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _navigationTreeKey++;
            _navigationAreaNotifier.value++;
          }
        });
      } else {
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  List<Map<String, dynamic>> _getFilteredFiles() {
    var filtered = _files;

    // Filtrar por pasta
    if (_selectedFolderId == null) {
      filtered = filtered.where((f) => f['folder_id'] == null).toList();
    } else {
      filtered = filtered.where((f) => f['folder_id'] == _selectedFolderId).toList();
    }

    // Aplicar pesquisa (nome ou descrição)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((file) {
        final filename = (file['filename'] ?? '').toString().toLowerCase();
        final description = (file['description'] ?? '').toString().toLowerCase();
        return filename.contains(query) || description.contains(query);
      }).toList();
    }

    // Aplicar filtro por tipo ou tag
    if (_filterType != 'none' && _filterValue != null) {
      filtered = filtered.where((file) {
        switch (_filterType) {
          case 'type':
            final mimeType = file['mime_type'] as String?;
            if (mimeType == null) return false;

            switch (_filterValue) {
              case 'image':
                return mimeType.startsWith('image/');
              case 'video':
                return mimeType.startsWith('video/');
              case 'document':
                return mimeType.contains('pdf') ||
                    mimeType.contains('document') ||
                    mimeType.contains('word') ||
                    mimeType.contains('text');
              case 'compressed':
                return mimeType.contains('zip') ||
                    mimeType.contains('rar') ||
                    mimeType.contains('7z') ||
                    mimeType.contains('tar') ||
                    mimeType.contains('gz');
              case 'design':
                return mimeType.contains('photoshop') ||
                    mimeType.contains('illustrator') ||
                    mimeType.contains('figma') ||
                    mimeType.contains('sketch');
              default:
                return true;
            }

          case 'tag':
            final fileTags = file['file_tags'] as List<dynamic>?;
            if (fileTags == null || fileTags.isEmpty) return false;

            final fileTagIds = fileTags
                .map((ft) => ft['tag']?['id'] as String?)
                .whereType<String>()
                .toList();

            return fileTagIds.contains(_filterValue);

          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case 'type':
        return 'Tipo de arquivo';
      case 'tag':
        return 'Tag';
      default:
        return 'Filtrar';
    }
  }

  List<String>? _getFilterOptions() {
    switch (_filterType) {
      case 'type':
        return ['image', 'video', 'document', 'compressed', 'design'];
      case 'tag':
        return _tags.map((tag) => tag['id'] as String).toList();
      default:
        return null;
    }
  }

  String _getFilterValueLabel(String value) {
    switch (_filterType) {
      case 'type':
        switch (value) {
          case 'image':
            return 'Imagem';
          case 'video':
            return 'Vídeo';
          case 'document':
            return 'Documento';
          case 'compressed':
            return 'Compactado';
          case 'design':
            return 'Design';
          default:
            return value;
        }
      case 'tag':
        final tag = _tags.firstWhere(
          (t) => t['id'] == value,
          orElse: () => {'name': value},
        );
        return tag['name'] as String;
      default:
        return value;
    }
  }

  /// Retorna o nome da empresa selecionada
  String _getSelectedCompanyName() {
    if (_selectedCompanyId == null) return '';

    for (final client in _clients) {
      final companies = (client['companies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      for (final company in companies) {
        if (company['id'] == _selectedCompanyId) {
          final clientName = client['name'] as String;
          final companyName = company['name'] as String;
          return '$clientName → $companyName';
        }
      }
    }
    return '';
  }

  /// Retorna as pastas raiz (sem parent_folder_id)
  List<Map<String, dynamic>> _getRootFolders(List<Map<String, dynamic>> folders) {
    return folders.where((f) => f['parent_folder_id'] == null).toList();
  }

  /// Retorna as subpastas de uma pasta específica
  List<Map<String, dynamic>> _getSubFolders(String parentId, List<Map<String, dynamic>> folders) {
    return folders.where((f) => f['parent_folder_id'] == parentId).toList();
  }

  /// Verifica se um texto corresponde à pesquisa (busca por palavras)
  bool _matchesSearch(String text, String query) {
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();

    // Dividir a query em palavras
    final queryWords = queryLower.split(RegExp(r'\s+'));

    // Todas as palavras da query devem estar presentes no texto
    return queryWords.every((word) => textLower.contains(word));
  }

  /// Constrói a árvore de navegação: Clientes → Empresas → Pastas
  List<Widget> _buildNavigationTree() {
    final widgets = <Widget>[];

    // Filtrar clientes por pesquisa
    var filteredClients = _clients;
    if (_navigationSearchQuery.isNotEmpty) {
      final query = _navigationSearchQuery.toLowerCase();

      filteredClients = _clients.where((client) {
        final clientName = client['name'] as String;
        final companies = (client['companies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        // Verifica se o nome do cliente corresponde
        if (_matchesSearch(clientName, query)) {
          return true;
        }

        // Verifica se alguma empresa corresponde
        final hasMatchingCompany = companies.any((company) {
          final companyName = company['name'] as String;
          return _matchesSearch(companyName, query);
        });

        return hasMatchingCompany;
      }).toList();
    }

    // Ordenar clientes alfabeticamente
    filteredClients.sort((a, b) {
      final nameA = (a['name'] as String).toLowerCase();
      final nameB = (b['name'] as String).toLowerCase();
      return nameA.compareTo(nameB);
    });

    for (final client in filteredClients) {
      final clientId = client['id'] as String;
      final clientName = client['name'] as String;
      final avatarUrl = client['avatar_url'] as String?;
      var companies = (client['companies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      // Ordenar empresas alfabeticamente
      companies.sort((a, b) {
        final nameA = (a['name'] as String).toLowerCase();
        final nameB = (b['name'] as String).toLowerCase();
        return nameA.compareTo(nameB);
      });

      // Filtrar empresas por pesquisa (se houver)
      var filteredCompanies = companies;
      if (_navigationSearchQuery.isNotEmpty) {
        filteredCompanies = companies.where((company) {
          final companyName = company['name'] as String;
          return _matchesSearch(companyName, _navigationSearchQuery);
        }).toList();
      }

      // Determinar se deve expandir automaticamente
      // Expande se: está selecionado OU há pesquisa ativa
      final shouldExpand = _selectedClientId == clientId || _navigationSearchQuery.isNotEmpty;

      // Cliente (nível 0)
      widgets.add(
        Theme(
          data: Theme.of(context).copyWith(
            listTileTheme: const ListTileThemeData(
              minVerticalPadding: 0,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          child: ExpansionTile(
            key: ValueKey('client_${clientId}_$_navigationTreeKey'),
            tilePadding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
            childrenPadding: EdgeInsets.zero,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 14),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: Text(clientName),
                ),
              ],
            ),
            initiallyExpanded: shouldExpand,
          children: filteredCompanies.map((company) {
            final companyId = company['id'] as String;
            final companyName = company['name'] as String;
            final isSelected = _selectedCompanyId == companyId;


            return Theme(
              data: Theme.of(context).copyWith(
                listTileTheme: const ListTileThemeData(
                  minVerticalPadding: 0,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: ExpansionTile(
                key: ValueKey('company_${companyId}_$_navigationTreeKey'),
                tilePadding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                childrenPadding: EdgeInsets.zero,
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.business,
                        size: 20,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        companyName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    ),
                  ],
                ),
                initiallyExpanded: isSelected,
              onExpansionChanged: (expanded) {

                if (expanded && !isSelected) {
                  _selectedClientId = clientId;
                  _selectedCompanyId = companyId; // ← ATUALIZA IMEDIATAMENTE!
                  // NÃO incrementa aqui - espera _loadCompanyData terminar e atualizar o cache
                  _loadCompanyData(companyId);
                } else {
                }
              },
              children: isSelected ? _buildFolderTree(companyId) : [],
              ),
            );
          }).toList(),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Constrói a árvore de pastas para a empresa selecionada
  List<Widget> _buildFolderTree(String companyId) {
    // Só mostra pastas se for a empresa atualmente selecionada
    if (_selectedCompanyId != companyId) {
      return [];
    }

    // Busca dados do cache da empresa
    final folders = _foldersByCompany[companyId] ?? [];
    final files = _filesByCompany[companyId] ?? [];

    final widgets = <Widget>[];

    // 1. Arquivos da raiz (sem pasta)
    final rootFilesCount = files.where((f) => f['folder_id'] == null).length;
    widgets.add(
      ListTile(
        selected: _selectedFolderId == null,
        leading: const Icon(Icons.folder_open, size: 20),
        title: Text('Todos os arquivos ($rootFilesCount)'),
        dense: true,
        onTap: () {
          _selectedFolderId = null;
          _filesAreaNotifier.value++;
        },
      ),
    );

    // 2. Pastas principais e suas subpastas
    final rootFolders = _getRootFolders(folders);
    for (final folder in rootFolders) {
      widgets.addAll(_buildFolderItem(folder, folders, files, level: 0));
    }

    return widgets;
  }

  /// Constrói um item de pasta e suas subpastas recursivamente
  List<Widget> _buildFolderItem(
    Map<String, dynamic> folder,
    List<Map<String, dynamic>> folders,
    List<Map<String, dynamic>> files,
    {required int level}
  ) {
    final widgets = <Widget>[];
    final folderId = folder['id'] as String;
    final folderName = folder['name'] as String;
    final isSelected = _selectedFolderId == folderId;
    final subFolders = _getSubFolders(folderId, folders);
    final filesCount = files.where((f) => f['folder_id'] == folderId).length;

    // Item da pasta atual
    widgets.add(
      Padding(
        padding: EdgeInsets.only(left: level * 16.0),
        child: ListTile(
          selected: isSelected,
          leading: Icon(subFolders.isNotEmpty ? Icons.folder : Icons.folder_outlined),
          title: Text('$folderName ($filesCount)'),
          dense: level > 0,
          onTap: () {
            _selectedFolderId = folderId;
            _filesAreaNotifier.value++;
          },
        ),
      ),
    );

    // Subpastas (recursivo)
    for (final subFolder in subFolders) {
      widgets.addAll(_buildFolderItem(subFolder, folders, files, level: level + 1));
    }

    return widgets;
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.contains('zip') || mimeType.contains('rar') || mimeType.contains('7z')) return Icons.folder_zip;
    
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 1100,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.folder_special, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecionar do Design Materials',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _selectedCompanyId != null
                            ? _getSelectedCompanyName()
                            : 'Selecione um cliente e empresa',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 32),

            // Selected count
            if (_selectedFileIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SimpleBadge(
                  label: '${_selectedFileIds.length} arquivo(s) selecionado(s)',
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),

            // Content
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _loadingNotifier,
                builder: (context, loading, __) {
                  return loading
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Navigation sidebar: Clientes → Empresas → Pastas
                        ValueListenableBuilder<int>(
                          valueListenable: _navigationAreaNotifier,
                          builder: (context, _, __) {
                            return SizedBox(
                              width: 300,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Campo de pesquisa para clientes/empresas (com mesmo padding do TableSearchFilterBar)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                    child: TextField(
                                      controller: _navigationSearchController,
                                      decoration: InputDecoration(
                                        hintText: 'Buscar cliente/empresa...',
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: _navigationSearchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _navigationSearchController.clear();
                                                  _navigationSearchQuery = '';
                                                  _navigationTreeKey++;
                                                  _navigationAreaNotifier.value++;
                                                },
                                              )
                                            : null,
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      onChanged: (value) {
                                        _navigationSearchQuery = value;
                                        _navigationTreeKey++;
                                        _navigationAreaNotifier.value++;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: ListView(
                                        children: _buildNavigationTree(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 16),

                        // Files grid
                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _filesAreaNotifier,
                            builder: (context, _, __) {
                              final filteredFiles = _getFilteredFiles();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Barra de busca e filtros (mesma da aba Design Materials)
                                  TableSearchFilterBar(
                                    searchHint: 'Buscar arquivo (nome ou descrição...)',
                                    onSearchChanged: (value) {
                                      _searchQuery = value;
                                      _filesAreaNotifier.value++;
                                    },
                                    filterType: _filterType,
                                    filterTypeLabel: 'Filtrar por',
                                    filterTypeOptions: const [
                                      FilterOption(value: 'none', label: 'Nenhum'),
                                      FilterOption(value: 'type', label: 'Tipo de Arquivo'),
                                      FilterOption(value: 'tag', label: 'Tag'),
                                    ],
                                    onFilterTypeChanged: (value) {
                                      if (value != null) {
                                        _filterType = value;
                                        _filterValue = null;
                                        _filesAreaNotifier.value++;
                                      }
                                    },
                                    filterValue: _filterValue,
                                    filterValueLabel: _getFilterLabel(),
                                    filterValueOptions: _getFilterOptions(),
                                    onFilterValueChanged: (value) {
                                      _filterValue = value;
                                      _filesAreaNotifier.value++;
                                    },
                                    filterValueLabelBuilder: _getFilterValueLabel,
                                  ),
                                  const SizedBox(height: 12),

                                  Expanded(
                                child: _selectedCompanyId == null
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.arrow_back,
                                              size: 48,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Selecione um cliente e empresa',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Use a navegação à esquerda',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : filteredFiles.isEmpty
                                        ? Center(
                                            child: Text(
                                              'Nenhum arquivo encontrado',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          )
                                    : GridView.builder(
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 150,
                                          childAspectRatio: 0.8,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: filteredFiles.length,
                                        itemBuilder: (context, index) {
                                          final file = filteredFiles[index];
                                          final fileId = file['id'] as String;
                                          final isSelected = _selectedFileIds.contains(fileId);
                                          final filename = file['filename'] as String;
                                          final mimeType = file['mime_type'] as String?;
                                          final driveFileId = file['drive_file_id'] as String?;
                                          final isImage = mimeType?.startsWith('image/') ?? false;
                                          final isVideo = mimeType?.startsWith('video/') ?? false;
                                          final fileTags = (file['tags'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

                                          final thumbnailUrl = driveFileId != null && (isImage || isVideo)
                                              ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w400'
                                              : null;

                                          return Card(
                                            clipBehavior: Clip.antiAlias,
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primaryContainer
                                                : null,
                                            child: InkWell(
                                              onTap: () {
                                                if (isSelected) {
                                                  _selectedFileIds.remove(fileId);
                                                } else {
                                                  _selectedFileIds.add(fileId);
                                                }
                                                _filesAreaNotifier.value++;
                                              },
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // Thumbnail
                                                  Expanded(
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: Container(
                                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                            child: thumbnailUrl != null
                                                                ? Image.network(
                                                                    thumbnailUrl,
                                                                    fit: BoxFit.cover,
                                                                    errorBuilder: (context, error, stackTrace) {
                                                                      return Center(
                                                                        child: Icon(
                                                                          _getFileIcon(mimeType),
                                                                          size: 32,
                                                                          color: Theme.of(context).colorScheme.primary,
                                                                        ),
                                                                      );
                                                                    },
                                                                  )
                                                                : Center(
                                                                    child: Icon(
                                                                      _getFileIcon(mimeType),
                                                                      size: 32,
                                                                      color: Theme.of(context).colorScheme.primary,
                                                                    ),
                                                                  ),
                                                          ),
                                                        ),
                                                        // Tags (canto superior esquerdo)
                                                        if (fileTags.isNotEmpty)
                                                          Positioned(
                                                            top: 4,
                                                            left: 4,
                                                            child: Wrap(
                                                              spacing: 4,
                                                              runSpacing: 4,
                                                              children: fileTags.take(2).map((tag) {
                                                                return Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xB3000000), // Black with 70% opacity
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Container(
                                                                        width: 8,
                                                                        height: 8,
                                                                        decoration: BoxDecoration(
                                                                          color: Color(int.parse('0xFF${tag['color']?.substring(1) ?? 'CCCCCC'}')),
                                                                          shape: BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(width: 4),
                                                                      Text(
                                                                        tag['name'] as String,
                                                                        style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontSize: 10,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ),
                                                          ),
                                                        // Checkmark de seleção (canto superior direito)
                                                        if (isSelected)
                                                          Positioned(
                                                            top: 4,
                                                            right: 4,
                                                            child: Container(
                                                              padding: const EdgeInsets.all(4),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.primary,
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: Icon(
                                                                Icons.check,
                                                                size: 16,
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Filename
                                                  Padding(
                                                    padding: const EdgeInsets.all(8),
                                                    child: Text(
                                                      filename,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                },
              ),
            ),

            // Actions
            const Divider(height: 32),
            ValueListenableBuilder<int>(
              valueListenable: _filesAreaNotifier,
              builder: (context, _, __) {
                final selectedFiles = _files.where((f) => _selectedFileIds.contains(f['id'])).toList();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _selectedFileIds.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(selectedFiles),
                      child: Text('Adicionar (${_selectedFileIds.length})'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

