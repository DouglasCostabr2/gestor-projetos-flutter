import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'google_drive_oauth_service.dart';
import 'task_files_repository.dart';

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
    return _taskProgress.putIfAbsent(taskId, () => ValueNotifier<double?>(null));
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
    final notifier = _taskProgress.putIfAbsent(taskId, () => ValueNotifier<double?>(0));
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
}

