import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'folder_service.dart';
import 'file_service.dart';
import 'upload_service.dart';

/// Serviço principal do Google Drive
/// 
/// Fachada que integra todos os serviços especializados:
/// - AuthService: Autenticação OAuth
/// - FolderService: Gerenciamento de pastas
/// - FileService: Gerenciamento de arquivos
/// - UploadService: Upload de arquivos
/// 
/// Este é o ponto de entrada principal para interagir com o Google Drive.
/// 
/// Exemplo de uso:
/// ```dart
/// final driveService = GoogleDriveService();
/// 
/// // Autenticar
/// final client = await driveService.getAuthedClient();
/// 
/// // Criar estrutura de pastas
/// final folderId = await driveService.createProjectFolder(
///   client: client,
///   clientName: 'Cliente ABC',
///   projectName: 'Projeto XYZ',
/// );
/// 
/// // Fazer upload
/// final uploaded = await driveService.uploadFile(
///   client: client,
///   folderId: folderId,
///   filename: 'documento.pdf',
///   bytes: pdfBytes,
///   mimeType: 'application/pdf',
/// );
/// ```
class GoogleDriveService {
  // Serviços especializados
  final _authService = GoogleDriveAuthService();
  final _folderService = GoogleDriveFolderService();
  final _fileService = GoogleDriveFileService();
  final _uploadService = GoogleDriveUploadService();

  // ========== AUTENTICAÇÃO ==========

  /// Obter cliente autenticado
  Future<http.Client> getAuthedClient() => _authService.getAuthedClient();

  /// Salvar refresh token
  Future<void> saveRefreshToken(String userId, String refreshToken) =>
      _authService.saveRefreshToken(userId, refreshToken);

  /// Verificar se tem token
  Future<bool> hasToken() => _authService.hasToken();

  /// Remover token
  Future<void> removeToken() => _authService.removeToken();

  // ========== PASTAS ==========

  /// Obter ou criar pasta raiz
  Future<String> getOrCreateRootFolder(http.Client client) =>
      _folderService.getOrCreateRootFolder(client);

  /// Obter ou criar subpasta
  Future<String> getOrCreateSubfolder({
    required http.Client client,
    required String parentFolderId,
    required String folderName,
  }) =>
      _folderService.getOrCreateSubfolder(
        client: client,
        parentFolderId: parentFolderId,
        folderName: folderName,
      );

  /// Renomear pasta
  Future<void> renameFolder({
    required http.Client client,
    required String folderId,
    required String newName,
  }) =>
      _folderService.renameFolder(
        client: client,
        folderId: folderId,
        newName: newName,
      );

  /// Deletar pasta
  Future<void> deleteFolder({
    required http.Client client,
    required String folderId,
  }) =>
      _folderService.deleteFolder(
        client: client,
        folderId: folderId,
      );

  /// Buscar pasta por nome
  Future<String?> findFolderByName({
    required http.Client client,
    required String parentFolderId,
    required String folderName,
  }) =>
      _folderService.findFolderByName(
        client: client,
        parentFolderId: parentFolderId,
        folderName: folderName,
      );

  // ========== ARQUIVOS ==========

  /// Deletar arquivo
  Future<void> deleteFile({
    required http.Client client,
    required String driveFileId,
  }) =>
      _fileService.deleteFile(
        client: client,
        driveFileId: driveFileId,
      );

  /// Renomear arquivo
  Future<void> renameFile({
    required http.Client client,
    required String fileId,
    required String newName,
  }) =>
      _fileService.renameFile(
        client: client,
        fileId: fileId,
        newName: newName,
      );

  /// Listar arquivos em pasta
  Future<List<dynamic>> listFilesInFolder({
    required http.Client client,
    required String folderId,
    String? namePattern,
  }) =>
      _fileService.listFilesInFolder(
        client: client,
        folderId: folderId,
        namePattern: namePattern,
      );

  /// Mover arquivo
  Future<void> moveFile({
    required http.Client client,
    required String fileId,
    required String currentParentId,
    required String newParentId,
  }) =>
      _fileService.moveFile(
        client: client,
        fileId: fileId,
        currentParentId: currentParentId,
        newParentId: newParentId,
      );

  /// Buscar arquivo por nome
  Future<String?> findFileByName({
    required http.Client client,
    required String folderId,
    required String fileName,
  }) =>
      _fileService.findFileByName(
        client: client,
        folderId: folderId,
        fileName: fileName,
      );

  // ========== UPLOAD ==========

  /// Fazer upload de arquivo
  Future<UploadedFile> uploadFile({
    required http.Client client,
    required String folderId,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    bool makePublic = true,
  }) =>
      _uploadService.uploadFile(
        client: client,
        folderId: folderId,
        filename: filename,
        bytes: bytes,
        mimeType: mimeType,
        makePublic: makePublic,
      );

  /// Upload de múltiplos arquivos
  Future<List<UploadedFile>> uploadMultipleFiles({
    required http.Client client,
    required String folderId,
    required List<Map<String, dynamic>> files,
    bool makePublic = true,
  }) =>
      _uploadService.uploadMultipleFiles(
        client: client,
        folderId: folderId,
        files: files,
        makePublic: makePublic,
      );

  /// Substituir arquivo
  Future<void> replaceFile({
    required http.Client client,
    required String fileId,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      _uploadService.replaceFile(
        client: client,
        fileId: fileId,
        bytes: bytes,
        mimeType: mimeType,
      );

  /// Verificar se arquivo existe
  Future<String?> checkFileExists({
    required http.Client client,
    required String folderId,
    required String filename,
  }) =>
      _uploadService.checkFileExists(
        client: client,
        folderId: folderId,
        filename: filename,
      );

  // ========== MÉTODOS DE ALTO NÍVEL ==========

  /// Criar estrutura completa de pastas para um projeto
  /// 
  /// Cria a hierarquia: Gestor de Projetos/Clientes/{Cliente}/{Empresa}/{Projeto}
  /// 
  /// Retorna: ID da pasta do projeto
  Future<String> createProjectFolder({
    required http.Client client,
    required String clientName,
    required String projectName,
    String? companyName,
  }) async {
    // Pasta raiz
    final rootId = await getOrCreateRootFolder(client);

    // Pasta "Clientes"
    final clientsId = await getOrCreateSubfolder(
      client: client,
      parentFolderId: rootId,
      folderName: 'Clientes',
    );

    // Pasta do cliente
    final clientId = await getOrCreateSubfolder(
      client: client,
      parentFolderId: clientsId,
      folderName: clientName,
    );

    // Pasta da empresa (se fornecida)
    String parentId = clientId;
    if (companyName != null && companyName.isNotEmpty) {
      parentId = await getOrCreateSubfolder(
        client: client,
        parentFolderId: clientId,
        folderName: companyName,
      );
    }

    // Pasta do projeto
    final projectId = await getOrCreateSubfolder(
      client: client,
      parentFolderId: parentId,
      folderName: projectName,
    );

    return projectId;
  }

  /// Criar estrutura completa de pastas para uma tarefa
  /// 
  /// Cria: {Projeto}/{Tarefa} com subpastas Assets, Briefing, Comentarios
  /// 
  /// Retorna: ID da pasta da tarefa
  Future<String> createTaskFolder({
    required http.Client client,
    required String projectFolderId,
    required String taskName,
  }) async {
    // Pasta da tarefa
    final taskId = await getOrCreateSubfolder(
      client: client,
      parentFolderId: projectFolderId,
      folderName: taskName,
    );

    // Subpastas da tarefa
    await Future.wait([
      getOrCreateSubfolder(
        client: client,
        parentFolderId: taskId,
        folderName: 'Assets',
      ),
      getOrCreateSubfolder(
        client: client,
        parentFolderId: taskId,
        folderName: 'Briefing',
      ),
      getOrCreateSubfolder(
        client: client,
        parentFolderId: taskId,
        folderName: 'Comentarios',
      ),
    ]);

    return taskId;
  }
}

