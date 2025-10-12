import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'google_drive_oauth_service.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/error_handler/error_handler.dart';

/// Serviço dedicado para gerenciar uploads de imagens do briefing
/// 
/// Este serviço encapsula toda a lógica de:
/// - Upload de imagens em cache para o Google Drive
/// - Renomeação de arquivos seguindo o padrão do projeto
/// - Limpeza de arquivos de cache
/// - Atualização de URLs no JSON do briefing
class BriefingImageService {
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
  Future<String> uploadCachedImages({
    required String briefingJson,
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
  }) async {
    final isSubTask = subTaskTitle != null;
    final taskType = isSubTask ? 'SubTask' : 'Task';
    
    debugPrint('🔄 BriefingImageService.uploadCachedImages ($taskType) - INICIANDO');
    if (companyName != null && companyName.isNotEmpty) {
      debugPrint('🏢 Empresa: $companyName');
    }

    try {
      final data = jsonDecode(briefingJson) as Map<String, dynamic>;
      final blocks = data['blocks'] as List?;

      if (blocks == null) {
        debugPrint('⚠️ Nenhum bloco encontrado');
        return briefingJson;
      }

      debugPrint('📋 Total de blocos: ${blocks.length}');

      // Contador para numeração sequencial das imagens
      int imageCounter = 1;

      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];

        if (block is Map && block['type'] == 'image') {
          final url = block['content'] as String?;
          debugPrint('🖼️ Bloco $i: imagem com URL: $url');

          // Verificar se é uma URL local (cache)
          if (url != null && url.startsWith('file://')) {
            debugPrint('💾 É uma URL local! Iniciando upload...');
            
            final uploadedUrl = await _uploadSingleImage(
              localUrl: url,
              clientName: clientName,
              projectName: projectName,
              taskTitle: taskTitle,
              companyName: companyName,
              subTaskTitle: subTaskTitle,
              sequenceNumber: imageCounter,
            );

            if (uploadedUrl != null) {
              // Atualizar URL no bloco
              block['content'] = uploadedUrl;
              imageCounter++;
            }
          }
        }
      }

      debugPrint('✅ BriefingImageService.uploadCachedImages ($taskType) - CONCLUÍDO');
      return jsonEncode(data);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'BriefingImageService.uploadCachedImages',
      );
      throw StorageException(
        'Erro ao processar imagens do briefing',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Fazer upload de uma única imagem
  Future<String?> _uploadSingleImage({
    required String localUrl,
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    required int sequenceNumber,
  }) async {
    try {
      final localPath = localUrl.substring(7); // Remove 'file://'
      final file = File(localPath);

      if (!await file.exists()) {
        debugPrint('⚠️ Arquivo não existe: $localPath');
        return null;
      }

      final isSubTask = subTaskTitle != null;
      final taskType = isSubTask ? 'SubTask' : 'Task';

      // Fazer upload para o Google Drive
      debugPrint('🚀 Iniciando upload para Google Drive ($taskType)...');
      final driveClient = await _driveService.getAuthedClient();

      final bytes = await file.readAsBytes();
      final extension = path.extension(localPath);

      // Criar nome no formato: Briefing-Task_Cliente-Projeto-01.ext
      final sequenceStr = sequenceNumber.toString().padLeft(2, '0');
      final titleForFilename = isSubTask ? subTaskTitle : taskTitle;
      final newFileName = 'Briefing-${titleForFilename}_$clientName-$projectName-$sequenceStr$extension';

      debugPrint('📤 Fazendo upload ($taskType): $newFileName (${bytes.length} bytes)');

      // Upload para pasta correta (task ou subtask)
      final uploadedFile = isSubTask
          ? await _driveService.uploadToSubTaskSubfolder(
              client: driveClient,
              clientName: clientName,
              projectName: projectName,
              taskName: taskTitle,
              subTaskName: subTaskTitle,
              subfolderName: 'Briefing',
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
              subfolderName: 'Briefing',
              filename: newFileName,
              bytes: bytes,
              mimeType: 'image/${extension.substring(1)}',
              companyName: companyName,
            );

      final publicUrl = uploadedFile.publicViewUrl;
      debugPrint('✅ Imagem do briefing enviada para Google Drive: $publicUrl');

      // Deletar arquivo do cache
      await _deleteCacheFile(file);

      return publicUrl;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'BriefingImageService._uploadSingleImage',
      );
      throw DriveException(
        'Erro ao fazer upload da imagem para o Google Drive',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletar arquivo de cache
  Future<void> _deleteCacheFile(File file) async {
    try {
      await file.delete();
      debugPrint('🗑️ Arquivo de cache deletado');
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar arquivo de cache: $e');
    }
  }

  /// Deletar imagem do Google Drive
  /// 
  /// Parâmetros:
  /// - [url]: URL da imagem no Google Drive
  Future<void> deleteImage(String url) async {
    if (!url.contains('drive.google.com')) {
      debugPrint('⚠️ URL não é do Google Drive: $url');
      return;
    }

    try {
      // Extrair o ID do arquivo da URL
      // Formato: https://drive.google.com/uc?export=view&id=FILE_ID
      final uri = Uri.parse(url);
      final fileId = uri.queryParameters['id'];
      
      if (fileId == null || fileId.isEmpty) {
        debugPrint('⚠️ ID do arquivo não encontrado na URL: $url');
        return;
      }

      debugPrint('🔥 Deletando imagem do Google Drive: $fileId');
      
      final driveClient = await _driveService.getAuthedClient();
      await _driveService.deleteFile(
        client: driveClient,
        driveFileId: fileId,
      );
      
      debugPrint('✅ Imagem deletada do Google Drive: $fileId');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'BriefingImageService.deleteImage',
      );
      throw DriveException(
        'Erro ao deletar imagem do Google Drive',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}

