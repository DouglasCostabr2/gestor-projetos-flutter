import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'briefing_image_service.dart';

/// Instância do serviço de imagens do briefing
final _briefingImageService = BriefingImageService();

/// Função helper para fazer upload de imagens em cache para o Google Drive (tarefas normais)
Future<String> uploadCustomBriefingCachedImages({
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
  String? companyName,
}) =>
    _briefingImageService.uploadCachedImages(
      briefingJson: briefingJson,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
    );

/// Função helper para fazer upload de imagens em cache de SUBTAREFAS para o Google Drive
Future<String> uploadCustomBriefingCachedImagesForSubTask({
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
  required String subTaskTitle,
  String? companyName,
}) =>
    _briefingImageService.uploadCachedImages(
      briefingJson: briefingJson,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
      subTaskTitle: subTaskTitle,
    );

/// Inicia o upload de imagens do briefing em background (não bloqueia)
///
/// Esta função é usada para fazer upload de imagens do briefing para o Google Drive
/// em background, sem bloquear a interface do usuário.
///
/// Parâmetros:
/// - [taskId]: ID da tarefa no banco de dados
/// - [briefingJson]: JSON do briefing contendo blocos com imagens locais (file://)
/// - [clientName]: Nome do cliente
/// - [projectName]: Nome do projeto
/// - [taskTitle]: Título da tarefa
/// - [companyName]: Nome da empresa (opcional)
/// - [isSubTask]: Se true, usa a função de upload para subtarefas
/// - [parentTaskTitle]: Título da tarefa pai (obrigatório se isSubTask = true)
///
/// Retorna: void (executa em background)
void startBriefingImagesBackgroundUpload({
  required String taskId,
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
  String? companyName,
  bool isSubTask = false,
  String? parentTaskTitle,
}) {
  if (briefingJson.isEmpty) return;

  final logPrefix = isSubTask ? 'SubTask' : 'Task';

  unawaited(() async {
    try {
      debugPrint('🔄 Iniciando upload de imagens do briefing em background ($logPrefix)...');

      final String finalBriefingJson;

      if (isSubTask && parentTaskTitle != null) {
        finalBriefingJson = await uploadCustomBriefingCachedImagesForSubTask(
          briefingJson: briefingJson,
          clientName: clientName,
          projectName: projectName,
          taskTitle: parentTaskTitle,
          subTaskTitle: taskTitle,
          companyName: companyName,
        );
      } else {
        finalBriefingJson = await uploadCustomBriefingCachedImages(
          briefingJson: briefingJson,
          clientName: clientName,
          projectName: projectName,
          taskTitle: taskTitle,
          companyName: companyName,
        );
      }

      // Atualizar a descrição da tarefa com as URLs do Drive
      await Supabase.instance.client.from('tasks').update({
        'description': finalBriefingJson,
      }).eq('id', taskId);

      debugPrint('✅ Upload de imagens do briefing concluído ($logPrefix)!');
    } catch (e) {
      debugPrint('⚠️ Erro ao fazer upload das imagens do briefing em background ($logPrefix): $e');
    }
  }());
}

