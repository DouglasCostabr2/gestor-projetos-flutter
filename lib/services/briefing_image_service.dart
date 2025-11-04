import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
    final isSubTask = subTaskTitle != null;
    final taskType = isSubTask ? 'SubTask' : 'Task';

    debugPrint('🔄🔄🔄 BriefingImageService.uploadCachedImages ($taskType) - INICIANDO');
    if (companyName != null && companyName.isNotEmpty) {
      debugPrint('🏢 Empresa: $companyName');
    }

    try {
      final data = jsonDecode(briefingJson) as Map<String, dynamic>;
      final blocks = data['blocks'] as List?;

      if (blocks == null) {
        debugPrint('⚠️⚠️⚠️ Nenhum bloco encontrado');
        return briefingJson;
      }

      debugPrint('📋📋📋 Total de blocos: ${blocks.length}');

      // Contador para numeração sequencial das imagens
      int imageCounter = 1;

      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        debugPrint('🔍🔍🔍 Processando bloco $i, type=${block is Map ? block['type'] : 'NOT MAP'}');

        if (block is Map && block['type'] == 'image') {
          debugPrint('🖼️🖼️🖼️ Bloco $i é uma imagem!');
          dynamic rawContent = block['content'];
          String? url;
          Map<String, dynamic>? contentObj; // quando o editor salva {url, caption}

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

          debugPrint('🖼️🖼️🖼️ Bloco $i: imagem com URL: $url');

          // Verificar se é uma URL local (cache)
          if (url != null && url.startsWith('file://')) {
            debugPrint('💾💾💾 É uma URL local! Iniciando upload...');

            final uploadedUrl = await _uploadSingleImage(
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

            if (uploadedUrl != null) {
              // Atualiza o bloco preservando o formato original
              if (contentObj != null) {
                contentObj['url'] = uploadedUrl;
                block['content'] = jsonEncode(contentObj);
              } else {
                block['content'] = uploadedUrl;
              }
              imageCounter++;
            }
          }
        }
      }

      debugPrint('✅✅✅ BriefingImageService.uploadCachedImages ($taskType) - CONCLUÍDO');
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
    required String subfolderName,
    required String filePrefix,
  }) async {
    try {
      debugPrint('🔍🔍🔍 [_uploadSingleImage] INICIANDO - localUrl: $localUrl');

      final localPath = localUrl.substring(7); // Remove 'file://'
      debugPrint('🔍🔍🔍 [_uploadSingleImage] localPath extraído: $localPath');

      final file = File(localPath);

      if (!await file.exists()) {
        debugPrint('⚠️⚠️⚠️ Arquivo não existe: $localPath');
        return null;
      }

      final isSubTask = subTaskTitle != null;
      final taskType = isSubTask ? 'SubTask' : 'Task';

      // Fazer upload para o Google Drive
      debugPrint('🚀🚀🚀 Iniciando upload para Google Drive ($taskType)...');
      debugPrint('🔍🔍🔍 [_uploadSingleImage] Tentando obter cliente autenticado...');

      // Tentar obter cliente autenticado
      final driveClient = await _driveService.getAuthedClient();
      debugPrint('🔍🔍🔍 [_uploadSingleImage] Cliente autenticado obtido com sucesso!');

      final bytes = await file.readAsBytes();
      final extension = path.extension(localPath);

      // Criar nome no formato: <filePrefix>-Task_Cliente-Projeto-01.ext
      final sequenceStr = sequenceNumber.toString().padLeft(2, '0');
      final titleForFilename = isSubTask ? subTaskTitle : taskTitle;
      final newFileName = '$filePrefix-${titleForFilename}_$clientName-$projectName-$sequenceStr$extension';

      debugPrint('📤 Fazendo upload ($taskType) para "$subfolderName": $newFileName (${bytes.length} bytes)');

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

      final publicUrl = uploadedFile.publicViewUrl;
      debugPrint('✅ Imagem enviada para Google Drive: $publicUrl');

      // Remover apenas arquivos que estejam no cache dedicado da aplicação
      await CacheFileService.deleteIfInAppCache(localPath);
      return publicUrl;
    } on ConsentRequired catch (e) {
      // Erro específico quando não há conta do Google Drive conectada
      debugPrint('⚠️ Google Drive não conectado: $e');
      throw DriveException(
        'Consentimento necessário',
        originalError: e,
      );
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

