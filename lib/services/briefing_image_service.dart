import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'google_drive_oauth_service.dart';
import 'interfaces/briefing_image_service_interface.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/error_handler/error_handler.dart';

import '../utils/cache_file_service.dart';

/// Serviço dedicado para gerenciar uploads de imagens do briefing
///
/// Este serviço encapsula toda a lógica de:
/// - Upload de imagens em cache para o Google Drive
/// - Renomeação de arquivos seguindo o padrão do projeto
/// - Limpeza de arquivos de cache
/// - Atualização de URLs no JSON do briefing
///
/// Implementa a interface IBriefingImageService para permitir desacoplamento
/// e facilitar testes com mocks.
class BriefingImageService implements IBriefingImageService {
  final GoogleDriveOAuthService _driveService = GoogleDriveOAuthService();

  /// Fazer upload de imagens em cache para o Google Drive
  ///
  /// Parâmetros:
  /// - [briefingJson]: JSON do briefing contendo blocos com imagens
  /// - [clientName]: Nome do cliente
  /// - [projectName]: Nome do projeto
  /// - [taskTitle]: Título da tarefa
  /// - [companyName]: Nome da empresa (opcional)
  /// - [subTaskTitle]: Título da subtarefa (opcional, se fornecido é subtarefa)
  ///
  /// Retorna: JSON atualizado com URLs do Google Drive
  @override
  Future<String> uploadCachedImages({
    required String briefingJson,
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    String? subfolderName,
    String? filePrefix,
  }) async {
    if (companyName != null && companyName.isNotEmpty) {}

    try {
      final data = jsonDecode(briefingJson) as Map<String, dynamic>;
      final blocks = data['blocks'] as List?;

      if (blocks == null) {
        return briefingJson;
      }

      // Contador para numeração sequencial das imagens
      int imageCounter = 1;

      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];

        if (block is Map && block['type'] == 'image') {
          dynamic rawContent = block['content'];
          String? url;
          Map<String, dynamic>?
              contentObj; // quando o editor salva {url, caption}

          if (rawContent is String) {
            // Pode ser uma URL simples ou um JSON string com {url, caption}
            try {
              final decoded = jsonDecode(rawContent);
              if (decoded is Map && decoded['url'] is String) {
                url = (decoded['url'] as String).trim();
                contentObj = Map<String, dynamic>.from(decoded);
              } else {
                url = rawContent.trim();
              }
            } catch (_) {
              url = rawContent.trim();
            }
          } else if (rawContent is Map) {
            // Caso raro: conteúdo já veio como mapa
            final u = rawContent['url'];
            if (u is String) {
              url = u.trim();
              contentObj = Map<String, dynamic>.from(rawContent);
            }
          }

          // Verificar se é uma URL local (cache)
          if (url != null && url.startsWith('file://')) {
            final result = await _uploadSingleImage(
              localUrl: url,
              clientName: clientName,
              projectName: projectName,
              taskTitle: taskTitle,
              companyName: companyName,
              subTaskTitle: subTaskTitle,
              sequenceNumber: imageCounter,
              subfolderName: subfolderName ?? 'Briefing',
              filePrefix: filePrefix ?? 'Briefing',
            );

            if (result != null) {
              final uploadedUrl = result['url'] ?? '';
              final filename = result['filename'];

              // Atualiza o bloco preservando o formato original
              if (contentObj != null) {
                contentObj['url'] = uploadedUrl;
                contentObj['filename'] = filename;
                block['content'] = jsonEncode(contentObj);
              } else {
                block['content'] = jsonEncode({
                  'url': uploadedUrl,
                  'caption': '',
                  'filename': filename,
                });
              }
              imageCounter++;
            }
          }
        }
      }

      return jsonEncode(data);
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'BriefingImageService.uploadCachedImages',
      );
      throw StorageException(
        'Erro ao processar imagens do briefing',
        originalError: e,
      );
    }
  }

  /// Fazer upload de uma única imagem
  Future<Map<String, String>?> _uploadSingleImage({
    required String localUrl,
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    required int sequenceNumber,
    required String subfolderName,
    required String filePrefix,
  }) async {
    try {
      final localPath = localUrl.substring(7); // Remove 'file://'

      final file = File(localPath);

      if (!await file.exists()) {
        return null;
      }

      final isSubTask = subTaskTitle != null;

      // Fazer upload para o Google Drive

      // Tentar obter cliente autenticado
      final driveClient = await _driveService.getAuthedClient();

      final bytes = await file.readAsBytes();
      final extension = path.extension(localPath);

      // Criar nome no formato: <filePrefix>-Task_Cliente-Projeto-01.ext
      final sequenceStr = sequenceNumber.toString().padLeft(2, '0');
      final titleForFilename = isSubTask ? subTaskTitle : taskTitle;
      final newFileName =
          '$filePrefix-${titleForFilename}_$clientName-$projectName-$sequenceStr$extension';

      // Upload para pasta correta (task ou subtask)
      final uploadedFile = isSubTask
          ? await _driveService.uploadToSubTaskSubfolder(
              client: driveClient,
              clientName: clientName,
              projectName: projectName,
              taskName: taskTitle,
              subTaskName: subTaskTitle,
              subfolderName: subfolderName,
              filename: newFileName,
              bytes: bytes,
              mimeType: 'image/${extension.substring(1)}',
              companyName: companyName,
            )
          : await _driveService.uploadToTaskSubfolder(
              client: driveClient,
              clientName: clientName,
              projectName: projectName,
              taskName: taskTitle,
              subfolderName: subfolderName,
              filename: newFileName,
              bytes: bytes,
              mimeType: 'image/${extension.substring(1)}',
              companyName: companyName,
            );

      final publicUrl = uploadedFile.publicViewUrl ?? '';

      // Remover apenas arquivos que estejam no cache dedicado da aplicação
      await CacheFileService.deleteIfInAppCache(localPath);
      return {'url': publicUrl, 'filename': newFileName};
    } on ConsentRequired catch (e) {
      // Erro específico quando não há conta do Google Drive conectada
      throw DriveException(
        'Consentimento necessário',
        originalError: e,
      );
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'BriefingImageService._uploadSingleImage',
      );
      throw DriveException(
        'Erro ao fazer upload da imagem para o Google Drive',
        originalError: e,
      );
    }
  }

  /// Deletar imagem do Google Drive
  ///
  /// Parâmetros:
  /// - [url]: URL da imagem no Google Drive
  Future<void> deleteImage(String url) async {
    if (!url.contains('drive.google.com')) {
      return;
    }

    try {
      // Extrair o ID do arquivo da URL
      // Formato: https://drive.google.com/uc?export=view&id=FILE_ID
      final uri = Uri.parse(url);
      final fileId = uri.queryParameters['id'];

      if (fileId == null || fileId.isEmpty) {
        return;
      }

      final driveClient = await _driveService.getAuthedClient();
      await _driveService.deleteFile(
        client: driveClient,
        driveFileId: fileId,
      );
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'BriefingImageService.deleteImage',
      );
      throw DriveException(
        'Erro ao deletar imagem do Google Drive',
        originalError: e,
      );
    }
  }
}
