import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_business/ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'package:my_business/services/design_materials_repository.dart';
import 'package:my_business/services/google_drive_oauth_service.dart';
import 'package:my_business/modules/common/organization_context.dart';
import 'folder_tree_view.dart';
import 'file_grid_view.dart';
import 'design_materials_dialogs.dart';

/// Main tab for managing design materials for a company
class DesignMaterialsTab extends StatefulWidget {
  final String companyId;
  final String companyName;
  final String clientName;

  const DesignMaterialsTab({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.clientName,
  });

  @override
  State<DesignMaterialsTab> createState() => _DesignMaterialsTabState();
}

class _DesignMaterialsTabState extends State<DesignMaterialsTab> {
  final _repository = DesignMaterialsRepository();
  final _driveService = GoogleDriveOAuthService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _tags = [];

  String? _selectedFolderId;

  // Filter state
  String _searchQuery = '';
  String _filterType = 'none';
  String? _filterValue;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await _repository.getFolders(widget.companyId);
      final files = await _repository.getFiles(widget.companyId);
      final tags = await _repository.getTags();

      setState(() {
        _folders = folders;
        _files = files;
        _tags = tags;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredFiles() {
    var filtered = _files;

    // Filter by folder
    if (_selectedFolderId != null) {
      filtered = filtered.where((f) => f['folder_id'] == _selectedFolderId).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((file) {
        final filename = (file['filename'] ?? '').toString().toLowerCase();
        final description = (file['description'] ?? '').toString().toLowerCase();
        return filename.contains(query) || description.contains(query);
      }).toList();
    }

    // Apply filter type and value
    if (_filterType != 'none' && _filterValue != null && _filterValue!.isNotEmpty) {
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
                       mimeType.contains('excel') ||
                       mimeType.contains('powerpoint');
              case 'compressed':
                return mimeType.contains('zip') ||
                       mimeType.contains('rar') ||
                       mimeType.contains('7z');
              case 'design':
                return mimeType.contains('photoshop') ||
                       mimeType.contains('postscript') ||
                       mimeType == 'image/vnd.adobe.photoshop';
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
            return 'Imagens';
          case 'video':
            return 'Vídeos';
          case 'document':
            return 'Documentos';
          case 'compressed':
            return 'Compactados';
          case 'design':
            return 'Design (PSD, AI)';
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

  Future<void> _createFolder({String? parentFolderId, String? parentFolderName}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateFolderDialog(parentFolderName: parentFolderName),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);

    try {
      // Get authenticated client
      final client = await _driveService.getAuthedClient();
      final orgName = OrganizationContext.currentOrganization?['name'] as String?;

      // Get parent folder's drive_folder_id if creating a subfolder
      String? parentDriveFolderId;
      if (parentFolderId != null) {
        final parentFolder = _folders.firstWhere(
          (f) => f['id'] == parentFolderId,
          orElse: () => <String, dynamic>{},
        );
        parentDriveFolderId = parentFolder['drive_folder_id'] as String?;

      }

      // Create folder in Google Drive
      final driveFolderId = await _driveService.createDesignMaterialsSubfolder(
        client: client,
        clientName: widget.clientName,
        companyName: widget.companyName,
        folderName: result['name'] as String,
        parentFolderId: parentDriveFolderId, // Use Drive ID, not DB ID
        organizationName: orgName,
      );


      // Create folder in database
      await _repository.createFolder(
        companyId: widget.companyId,
        name: result['name'] as String,
        description: result['description'] as String?,
        parentFolderId: parentFolderId, // DB parent ID
        driveFolderId: driveFolderId, // Drive folder ID
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasta criada com sucesso')),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar pasta: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final currentName = folder['name'] as String;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        currentName: currentName,
        title: 'Renomear Pasta',
      ),
    );

    if (newName == null || newName == currentName || !mounted) return;

    setState(() => _loading = true);

    try {
      final driveFolderId = folder['drive_folder_id'] as String?;
      
      if (driveFolderId != null) {
        // Rename in Google Drive
        final client = await _driveService.getAuthedClient();
        await _driveService.renameDesignMaterialsFolder(
          client: client,
          folderId: driveFolderId,
          newName: newName,
        );
      }

      // Update in database
      await _repository.updateFolder(
        folderId: folder['id'] as String,
        name: newName,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasta renomeada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao renomear pasta: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Excluir Pasta',
        message: 'Tem certeza que deseja excluir a pasta "${folder['name']}"? '
            'Todos os arquivos e subpastas também serão excluídos.',
        confirmText: 'Excluir',
        cancelText: 'Cancelar',
        isDestructive: true,
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      final driveFolderId = folder['drive_folder_id'] as String?;
      
      if (driveFolderId != null) {
        // Delete from Google Drive
        final client = await _driveService.getAuthedClient();
        await _driveService.deleteDesignMaterialsFolder(
          client: client,
          folderId: driveFolderId,
        );
      }

      // Delete from database (cascade deletes files and subfolders)
      await _repository.deleteFolder(folder['id'] as String);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasta excluída com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir pasta: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadFiles() async {
    final selectedFiles = await showDialog<List<PlatformFile>>(
      context: context,
      builder: (context) => UploadFilesDialog(
        folderName: _selectedFolderId != null
            ? _folders.firstWhere((f) => f['id'] == _selectedFolderId)['name'] as String?
            : null,
      ),
    );

    if (selectedFiles == null || selectedFiles.isEmpty || !mounted) return;

    setState(() => _loading = true);

    try {
      final client = await _driveService.getAuthedClient();
      final orgName = OrganizationContext.currentOrganization?['name'] as String?;

      // Get or create the Drive folder ID
      String driveFolderId;
      if (_selectedFolderId != null) {
        final folder = _folders.firstWhere((f) => f['id'] == _selectedFolderId);
        driveFolderId = folder['drive_folder_id'] as String;
      } else {
        // Upload to root Design Materials folder
        driveFolderId = await _driveService.ensureDesignMaterialsFolder(
          client,
          widget.clientName,
          widget.companyName,
          organizationName: orgName,
        );
      }

      // Upload each file
      for (final file in selectedFiles) {
        // Detectar MIME type corretamente (MESMO SISTEMA DOS ASSETS)
        String? mimeType;
        if (file.extension != null) {
          final ext = file.extension!.toLowerCase();
          switch (ext) {
            // Imagens
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'png':
              mimeType = 'image/png';
              break;
            case 'gif':
              mimeType = 'image/gif';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
            case 'svg':
              mimeType = 'image/svg+xml';
              break;
            // Vídeos
            case 'mp4':
              mimeType = 'video/mp4';
              break;
            case 'mov':
              mimeType = 'video/quicktime';
              break;
            case 'avi':
              mimeType = 'video/x-msvideo';
              break;
            case 'webm':
              mimeType = 'video/webm';
              break;
            // PDFs e documentos
            case 'pdf':
              mimeType = 'application/pdf';
              break;
            case 'doc':
              mimeType = 'application/msword';
              break;
            case 'docx':
              mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            case 'xls':
              mimeType = 'application/vnd.ms-excel';
              break;
            case 'xlsx':
              mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
              break;
            case 'ppt':
              mimeType = 'application/vnd.ms-powerpoint';
              break;
            case 'pptx':
              mimeType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
              break;
            // Arquivos compactados
            case 'zip':
              mimeType = 'application/zip';
              break;
            case 'rar':
              mimeType = 'application/x-rar-compressed';
              break;
            case '7z':
              mimeType = 'application/x-7z-compressed';
              break;
            // PSD e AI
            case 'psd':
              mimeType = 'image/vnd.adobe.photoshop';
              break;
            case 'ai':
              mimeType = 'application/postscript';
              break;
            default:
              mimeType = 'application/octet-stream';
          }
        }


        final uploaded = await _driveService.uploadToDesignMaterialsFolder(
          client: client,
          folderId: driveFolderId,
          filename: file.name,
          bytes: file.bytes!,
          mimeType: mimeType,
        );


        // Save to database (INCLUINDO MIME TYPE!)
        await _repository.createFile(
          companyId: widget.companyId,
          filename: file.name,
          driveFileId: uploaded.id,
          folderId: _selectedFolderId,
          fileSizeBytes: file.size,
          mimeType: mimeType, // ✅ SALVAR MIME TYPE!
          driveFileUrl: uploaded.publicViewUrl,
          driveThumbnailUrl: uploaded.thumbnailLink,
        );

      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedFiles.length} arquivo(s) enviado(s) com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar arquivos: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erro: $_error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadData,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    final filteredFiles = _getFilteredFiles();

    return Row(
      children: [
        // Left sidebar: Folders
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _createFolder(),
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text('Nova Pasta'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FolderTreeView(
                  folders: _folders,
                  selectedFolderId: _selectedFolderId,
                  onFolderSelected: (folderId) {
                    setState(() => _selectedFolderId = folderId);
                  },
                  onFolderRename: _renameFolder,
                  onFolderDelete: _deleteFolder,
                  onAddSubfolder: (folder) {
                    _createFolder(
                      parentFolderId: folder['id'] as String,
                      parentFolderName: folder['name'] as String,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Main content: Files
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toolbar
              _buildToolbar(filteredFiles.length),
              const Divider(height: 1),
              // Files grid
              Expanded(
                child: FileGridView(
                  files: filteredFiles,
                  onFileRename: _renameFile,
                  onFileDelete: _deleteFile,
                  onFileDownload: _downloadFile,
                  onManageTags: _manageFileTags,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(int fileCount) {
    return TableSearchFilterBar(
      searchHint: 'Buscar arquivo (nome ou descrição...)',
      onSearchChanged: (value) {
        setState(() => _searchQuery = value);
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
          setState(() {
            _filterType = value;
            _filterValue = null;
          });
        }
      },
      filterValue: _filterValue,
      filterValueLabel: _getFilterLabel(),
      filterValueOptions: _getFilterOptions(),
      filterValueLabelBuilder: _getFilterValueLabel,
      onFilterValueChanged: (value) {
        setState(() => _filterValue = value?.isEmpty == true ? null : value);
      },
      actionButton: FilledButton.icon(
        onPressed: _uploadFiles,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }

  Future<void> _renameFile(Map<String, dynamic> file) async {
    final currentName = file['filename'] as String;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        currentName: currentName,
        title: 'Renomear Arquivo',
      ),
    );

    if (newName == null || newName == currentName || !mounted) return;

    setState(() => _loading = true);

    try {
      // Garantir que a extensão está presente
      final originalExtension = _getFileExtension(currentName);
      final newExtension = _getFileExtension(newName);

      String finalName = newName;

      // Se o novo nome não tem extensão, mas o original tinha, adicionar a extensão original
      if (newExtension == null && originalExtension != null) {
        finalName = '$newName.$originalExtension';
      }

      final driveFileId = file['drive_file_id'] as String?;

      if (driveFileId != null) {
        // Rename in Google Drive
        final client = await _driveService.getAuthedClient();
        await _driveService.renameDesignMaterialsFile(
          client: client,
          fileId: driveFileId,
          newName: finalName,
        );
      }

      // Update in database
      await _repository.updateFile(
        fileId: file['id'] as String,
        filename: finalName,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo renomeado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao renomear arquivo: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  /// Extrai a extensão do arquivo (sem o ponto)
  String? _getFileExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filename.length - 1) return null;
    return filename.substring(lastDot + 1).toLowerCase();
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Excluir Arquivo',
        message: 'Tem certeza que deseja excluir o arquivo "${file['filename']}"?',
        confirmText: 'Excluir',
        cancelText: 'Cancelar',
        isDestructive: true,
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      final driveFileId = file['drive_file_id'] as String?;

      if (driveFileId != null) {
        // Delete from Google Drive
        final client = await _driveService.getAuthedClient();
        await _driveService.deleteDesignMaterialsFile(
          client: client,
          fileId: driveFileId,
        );
      }

      // Delete from database
      await _repository.deleteFile(file['id'] as String);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo excluído com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir arquivo: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final url = file['drive_file_url'] as String?;
    if (url != null && url.isNotEmpty) {
      // Open in browser for download
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o link do arquivo')),
          );
        }
      }
    }
  }

  Future<void> _manageFileTags(Map<String, dynamic> file) async {
    final fileTags = file['file_tags'] as List<dynamic>?;
    final currentTagIds = fileTags
            ?.map((ft) => ft['tag']?['id'] as String?)
            .whereType<String>()
            .toList() ??
        [];

    final newTagIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => ManageTagsDialog(
        availableTags: _tags,
        currentTagIds: currentTagIds,
        itemName: file['filename'] as String,
        isFolder: false,
      ),
    );

    if (newTagIds == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final fileId = file['id'] as String;

      // Remove tags that are no longer selected
      for (final tagId in currentTagIds) {
        if (!newTagIds.contains(tagId)) {
          await _repository.removeTagFromFile(fileId, tagId);
        }
      }

      // Add new tags
      for (final tagId in newTagIds) {
        if (!currentTagIds.contains(tagId)) {
          await _repository.addTagToFile(fileId, tagId);
        }
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tags atualizadas com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar tags: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }
}

