import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:my_business/services/google_drive_oauth_service.dart';
import 'package:my_business/services/upload_manager.dart' as legacy_upload;

/// Inicia o upload de assets (imagens, arquivos, vídeos) em background
/// 
/// Esta função é usada para fazer upload de assets para o Google Drive
/// em background, sem bloquear a interface do usuário.
/// 
/// Parâmetros:
/// - [taskId]: ID da tarefa no banco de dados
/// - [clientName]: Nome do cliente
/// - [projectName]: Nome do projeto
/// - [taskTitle]: Título da tarefa
/// - [assetsImages]: Lista de imagens para upload
/// - [assetsFiles]: Lista de arquivos para upload
/// - [assetsVideos]: Lista de vídeos para upload
/// - [companyName]: Nome da empresa (opcional) — quando informado, os arquivos irão para
///   Gestor de Projetos/Organizações/{Org}/Clientes/{Cliente}/{Empresa}/{Projeto}/{Tarefa}/Assets
///   (sem empresa usa o caminho antigo sem o nível {Empresa})
/// - [context]: BuildContext para mostrar SnackBar (opcional)
/// - [driveService]: Instância do GoogleDriveOAuthService (opcional, cria uma nova se não fornecido)
///
/// Retorna: void (executa em background)
Future<void> startAssetsBackgroundUpload({
  required String taskId,
  required String clientName,
  required String projectName,
  required String taskTitle,
  required List<PlatformFile> assetsImages,
  required List<PlatformFile> assetsFiles,
  required List<PlatformFile> assetsVideos,
  String? companyName,
  BuildContext? context,
  GoogleDriveOAuthService? driveService,
}) async {
  // Verificar se há assets para upload
  if (assetsImages.isEmpty && assetsFiles.isEmpty && assetsVideos.isEmpty) {
    return;
  }

  try {
    final drive = driveService ?? GoogleDriveOAuthService();
    
    // Função helper para obter cliente autenticado
    Future<auth.AuthClient?> ensureClient() async {
      try {
        return await drive.getAuthedClient();
      } catch (e) {
        debugPrint('⚠️ Erro ao obter cliente autenticado: $e');
        if (context != null && context.mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Conectar ao Google Drive'),
              content: const Text('É necessário conectar ao Google Drive para fazer upload dos arquivos.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Conectar'),
                ),
              ],
            ),
          );
          if (ok == true) {
            try {
              return await drive.getAuthedClient();
            } catch (_) {
              return null;
            }
          }
        }
        return null;
      }
    }

    final authed = await ensureClient();
    if (authed == null) {
      debugPrint('⚠️ Cliente não autenticado, upload de assets cancelado');
      return;
    }

    // Criar lista de items para upload
    final items = <legacy_upload.MemoryUploadItem>[];
    
    void addList(List<PlatformFile> list, String category) {
      for (final f in list.where((f) => f.bytes != null)) {
        items.add(legacy_upload.MemoryUploadItem(
          name: f.name,
          bytes: f.bytes!,
          mimeType: mime.lookupMimeType(f.name),
          subfolderName: 'Assets',
          category: category,
        ));
      }
    }
    
    addList(assetsImages, 'assets');
    addList(assetsFiles, 'assets');
    addList(assetsVideos, 'assets');

    if (items.isEmpty) {
      debugPrint('⚠️ Nenhum item válido para upload');
      return;
    }

    // Dispara upload em background e não aguarda
    debugPrint('🔄 Iniciando upload de ${items.length} assets em background...');
    unawaited(legacy_upload.UploadManager.instance.startAssetsUploadWithClient(
      client: authed,
      taskId: taskId,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      items: items,
      companyName: companyName,
    ));
    
    // Mostrar feedback visual
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviando arquivos em segundo plano...')),
      );
    }
    
    debugPrint('✅ Upload de assets iniciado com sucesso!');
  } catch (e) {
    debugPrint('⚠️ Erro ao iniciar upload de assets: $e');
  }
}

