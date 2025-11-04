import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../google_drive/upload_service.dart';

/// Interface para o serviço do Google Drive
///
/// Define o contrato público para interação com o Google Drive.
/// Permite desacoplamento e facilita testes com mocks.
///
/// NOTA: Esta interface define apenas os métodos essenciais usados pelos organisms.
/// Para funcionalidades avançadas, use a implementação concreta GoogleDriveService.
///
/// ## Implementações:
/// - `GoogleDriveService` - Implementação principal
/// - `MockGoogleDriveService` - Mock para testes
///
/// ## Uso:
/// ```dart
/// final driveService = serviceLocator.get<IGoogleDriveService>();
/// final client = await driveService.getAuthedClient();
/// ```
abstract class IGoogleDriveService {
  // ========== AUTENTICAÇÃO ==========

  /// Obtém um cliente HTTP autenticado para o Google Drive
  Future<http.Client> getAuthedClient();

  /// Salva o refresh token do usuário
  Future<void> saveRefreshToken(String userId, String refreshToken);

  /// Verifica se o usuário tem um token salvo
  Future<bool> hasToken();

  /// Remove o token do usuário
  Future<void> removeToken();

  // ========== PASTAS ==========

  /// Cria ou obtém a pasta raiz do projeto no Google Drive
  Future<String> getOrCreateRootFolder(http.Client client);

  /// Cria ou obtém uma subpasta
  Future<String> getOrCreateSubfolder({
    required http.Client client,
    required String parentFolderId,
    required String folderName,
  });

  /// Cria a estrutura de pastas para um projeto
  Future<String> createProjectFolder({
    required http.Client client,
    required String clientName,
    required String projectName,
  });

  /// Renomeia uma pasta
  Future<void> renameFolder({
    required http.Client client,
    required String folderId,
    required String newName,
  });

  /// Deleta uma pasta
  Future<void> deleteFolder({
    required http.Client client,
    required String folderId,
  });

  // ========== ARQUIVOS ==========

  /// Faz upload de um arquivo
  Future<UploadedFile> uploadFile({
    required http.Client client,
    required String folderId,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    bool makePublic = true,
  });

  /// Deleta um arquivo
  Future<void> deleteFile({
    required http.Client client,
    required String driveFileId,
  });

  /// Renomeia um arquivo
  Future<void> renameFile({
    required http.Client client,
    required String fileId,
    required String newName,
  });

  /// Lista arquivos em uma pasta
  Future<List<dynamic>> listFilesInFolder({
    required http.Client client,
    required String folderId,
    String? namePattern,
  });

  /// Move um arquivo para outra pasta
  Future<void> moveFile({
    required http.Client client,
    required String fileId,
    required String currentParentId,
    required String newParentId,
  });
}

