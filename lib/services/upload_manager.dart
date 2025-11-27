import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'google_drive_oauth_service.dart';
import 'task_files_repository.dart';
import '../utils/cache_file_service.dart';

class MemoryUploadItem {
  final String name;
  final List<int> bytes;
  final String? mimeType;
  final String subfolderName; // e.g., 'Assets', 'Briefing'
  final String category; // e.g., 'assets', 'briefing'
  MemoryUploadItem({
    required this.name,
    required this.bytes,
    required this.subfolderName,
    required this.category,
    this.mimeType,
  });
}

/// Singleton manager for background uploads to Google Drive with simple progress per task
class UploadManager {
  UploadManager._internal();
  static final UploadManager instance = UploadManager._internal();

  final _drive = GoogleDriveOAuthService();
  final _repo = TaskFilesRepository();

  // taskId -> ValueNotifier<double?> (null = no active job, 0..1 progress value)
  final Map<String, ValueNotifier<double?>> _taskProgress = {};

  ValueListenable<double?> progressOf(String taskId) {
    return _taskProgress.putIfAbsent(
        taskId, () => ValueNotifier<double?>(null));
  }

  Future<void> startAssetsUploadWithClient({
    required auth.AuthClient client,
    required String taskId,
    required String clientName,
    required String projectName,
    required String taskTitle,
    required List<MemoryUploadItem> items,
    String? companyName,
    bool isSubTask = false,
    String? parentTaskTitle,
  }) async {
    if (items.isEmpty) return;
    final notifier =
        _taskProgress.putIfAbsent(taskId, () => ValueNotifier<double?>(0));
    notifier.value = 0.0;
    try {
      final total = items.length;
      var done = 0;
      for (final it in items) {
        // Upload usando método apropriado (task ou subtask)
        final UploadedDriveFile up;

        if (isSubTask && parentTaskTitle != null) {
          // Upload para subtask: .../Task/Subtask/{SubTaskName}/Assets/
          up = await _drive.uploadToSubTaskSubfolder(
            client: client,
            clientName: clientName,
            projectName: projectName,
            taskName: parentTaskTitle,
            subTaskName: taskTitle,
            subfolderName: it.subfolderName,
            filename: it.name,
            bytes: it.bytes,
            mimeType: it.mimeType,
            companyName: companyName,
          );
        } else {
          // Upload para task normal: .../Task/Assets/
          up = await _drive.uploadToTaskSubfolderResumable(
            client: client,
            clientName: clientName,
            projectName: projectName,
            taskName: taskTitle,
            subfolderName: it.subfolderName,
            filename: it.name,
            bytes: it.bytes,
            mimeType: it.mimeType,
            companyName: companyName,
            onProgress: (progress) {
              // Atualizar progresso geral
              final itemProgress = (done + progress) / total;
              notifier.value = itemProgress;
            },
          );
        }

        await _repo.saveFile(
          taskId: taskId,
          filename: it.name,
          sizeBytes: it.bytes.length,
          mimeType: it.mimeType,
          driveFileId: up.id,
          driveFileUrl: up.publicViewUrl,
          category: it.category,
        );

        done += 1;
        notifier.value = done / total;
      }
    } catch (e) {
      // Mark as finished to hide the bar; errors are best-effort here
      notifier.value = 1.0;
    } finally {
      // Keep progress visible briefly, then clear
      await Future<void>.delayed(const Duration(seconds: 1));
      notifier.value = null;
    }
  }

  /// Salva arquivos localmente primeiro e faz upload em background
  /// Retorna imediatamente após salvar localmente, permitindo que a UI mostre os arquivos
  Future<void> startAssetsUploadWithLocalCache({
    required auth.AuthClient client,
    required String taskId,
    required String clientName,
    required String projectName,
    required String taskTitle,
    required List<MemoryUploadItem> items,
    String? companyName,
    bool isSubTask = false,
    String? parentTaskTitle,
  }) async {
    if (items.isEmpty) return;

    // 1. Salvar arquivos localmente e criar registros no banco IMEDIATAMENTE
    final fileRecords = <Map<String, dynamic>>[];
    for (final it in items) {
      try {
        // Salvar bytes em arquivo físico no cache
        final file = await CacheFileService.saveBytesToCache(it.bytes, it.name);
        // Usar file:/// path para que Image.network possa ler (se suportado) ou Image.file
        // Vamos salvar como URL file:// no banco para padronizar
        final localUrl = 'file://${file.path}';

        // Salvar arquivo no banco com URL local (temporária)
        final fileId = await _repo.saveFile(
          taskId: taskId,
          filename: it.name,
          sizeBytes: it.bytes.length,
          mimeType: it.mimeType,
          driveFileId: '', // Vazio por enquanto
          driveFileUrl: localUrl, // IMPORTANTE: Salvar a URL local aqui
          category: it.category,
          localPath: localUrl,
          isLocal: true,
        );

        fileRecords.add({
          'fileId': fileId,
          'item': it,
        });
      } catch (e) {
        // Ignora erros individuais
      }
    }

    // 2. Fazer upload em background e atualizar registros
    final notifier =
        _taskProgress.putIfAbsent(taskId, () => ValueNotifier<double?>(0));
    notifier.value = 0.0;

    // Upload em background (não aguarda)
    _uploadInBackground(
      client: client,
      taskId: taskId,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      fileRecords: fileRecords,
      companyName: companyName,
      isSubTask: isSubTask,
      parentTaskTitle: parentTaskTitle,
      notifier: notifier,
    );
  }

  Future<void> _uploadInBackground({
    required auth.AuthClient client,
    required String taskId,
    required String clientName,
    required String projectName,
    required String taskTitle,
    required List<Map<String, dynamic>> fileRecords,
    String? companyName,
    bool isSubTask = false,
    String? parentTaskTitle,
    required ValueNotifier<double?> notifier,
  }) async {
    try {
      final total = fileRecords.length;
      var done = 0;

      for (final record in fileRecords) {
        final fileId = record['fileId'] as String;
        final it = record['item'] as MemoryUploadItem;

        try {
          // Upload usando método apropriado (task ou subtask)
          final UploadedDriveFile up;

          if (isSubTask && parentTaskTitle != null) {
            up = await _drive.uploadToSubTaskSubfolder(
              client: client,
              clientName: clientName,
              projectName: projectName,
              taskName: parentTaskTitle,
              subTaskName: taskTitle,
              subfolderName: it.subfolderName,
              filename: it.name,
              bytes: it.bytes,
              mimeType: it.mimeType,
              companyName: companyName,
            );
          } else {
            up = await _drive.uploadToTaskSubfolderResumable(
              client: client,
              clientName: clientName,
              projectName: projectName,
              taskName: taskTitle,
              subfolderName: it.subfolderName,
              filename: it.name,
              bytes: it.bytes,
              mimeType: it.mimeType,
              companyName: companyName,
              onProgress: (progress) {
                final itemProgress = (done + progress) / total;
                notifier.value = itemProgress;
              },
            );
          }

          // Atualizar registro no banco com URLs do Drive
          await _repo.updateFileUrls(
            fileId: fileId,
            driveFileId: up.id,
            driveFileUrl: up.publicViewUrl ?? '',
          );
        } catch (e) {
          // Se falhar o upload de um arquivo, continua com os outros
        }

        done += 1;
        notifier.value = done / total;
      }
    } catch (e) {
      notifier.value = 1.0;
    } finally {
      await Future<void>.delayed(const Duration(seconds: 1));
      notifier.value = null;
    }
  }
}
