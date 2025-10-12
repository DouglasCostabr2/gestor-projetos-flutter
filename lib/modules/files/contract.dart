import 'package:googleapis_auth/auth_io.dart' as auth;

/// Contrato público do módulo de arquivos
/// Define as operações disponíveis para gestão de arquivos (Google Drive)
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de arquivos.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class FilesContract {
  /// Salvar arquivo no banco de dados (task_files)
  Future<void> saveFile({
    required String taskId,
    required String filename,
    required int sizeBytes,
    required String? mimeType,
    required String driveFileId,
    required String? driveFileUrl,
    String? category,
    String? commentId,
  });

  /// Buscar arquivos de uma tarefa
  Future<List<Map<String, dynamic>>> getTaskFiles(String taskId);

  /// Deletar arquivo
  Future<void> deleteFile(String fileId);

  /// Obter cliente OAuth do Google Drive para o usuário atual
  Future<auth.AuthClient?> getGoogleDriveClient();

  /// Verificar se usuário tem Google Drive conectado
  Future<bool> hasGoogleDriveConnected();

  /// Salvar token de refresh do Google Drive
  Future<void> saveGoogleDriveRefreshToken(String refreshToken);

  /// Fazer upload de múltiplos arquivos para o Google Drive
  Future<void> uploadFilesToDrive({
    required String taskId,
    required String projectName,
    required List<MemoryUploadItem> items,
    required Function(int current, int total) onProgress,
  });
}

/// Item de upload em memória
class MemoryUploadItem {
  final String name;
  final List<int> bytes;
  final String? mimeType;
  final String subfolderName;
  final String category;

  MemoryUploadItem({
    required this.name,
    required this.bytes,
    required this.subfolderName,
    required this.category,
    this.mimeType,
  });
}

