import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/app_update.dart';

/// Serviço responsável por verificar e gerenciar atualizações do aplicativo
class UpdateService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final Dio _dio = Dio();

  /// Callback para reportar progresso do download (0.0 a 1.0)
  void Function(double progress)? onDownloadProgress;

  /// Verifica se há uma atualização disponível
  ///
  /// Retorna [AppUpdate] se houver uma versão mais recente disponível,
  /// ou null se já estiver na versão mais recente.
  ///
  /// Exemplo:
  /// ```dart
  /// final updateService = UpdateService();
  /// final update = await updateService.checkForUpdates();
  /// if (update != null) {
  ///   print('Nova versão disponível: ${update.version}');
  /// }
  /// ```
  Future<AppUpdate?> checkForUpdates() async {
    try {
      // 1. Obter versão atual do app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Buscar versão mais recente no Supabase
      final response = await _supabase
          .from('app_versions')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final latestVersion = response['version'] as String;

      // 3. Comparar versões
      if (_isNewerVersion(latestVersion, currentVersion)) {
        final update = AppUpdate.fromJson(response);

        // Verificar se a versão atual está abaixo da mínima suportada
        if (update.minSupportedVersion != null) {
          if (_isNewerVersion(update.minSupportedVersion!, currentVersion)) {
            return AppUpdate(
              version: update.version,
              downloadUrl: update.downloadUrl,
              releaseNotes: update.releaseNotes,
              isMandatory: true, // Forçar atualização
              minSupportedVersion: update.minSupportedVersion,
              createdAt: update.createdAt,
            );
          }
        }

        return update;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Compara duas versões no formato semântico (ex: "1.2.3")
  ///
  /// Retorna true se [newVersion] é mais recente que [currentVersion]
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Garantir que ambas tenham 3 partes (major.minor.patch)
      while (newParts.length < 3) {
        newParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      // Comparar major
      if (newParts[0] > currentParts[0]) return true;
      if (newParts[0] < currentParts[0]) return false;

      // Comparar minor
      if (newParts[1] > currentParts[1]) return true;
      if (newParts[1] < currentParts[1]) return false;

      // Comparar patch
      if (newParts[2] > currentParts[2]) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Baixa o instalador da atualização
  ///
  /// Retorna o caminho do arquivo baixado ou null em caso de erro.
  ///
  /// Exemplo:
  /// ```dart
  /// final updateService = UpdateService();
  /// updateService.onDownloadProgress = (progress) {
  ///   print('Progresso: ${(progress * 100).toStringAsFixed(1)}%');
  /// };
  /// final filePath = await updateService.downloadUpdate(update);
  /// ```
  Future<String?> downloadUpdate(AppUpdate update) async {
    try {
      // Obter diretório temporário
      final tempDir = await getTemporaryDirectory();
      final fileName = 'MyBusiness-Setup-${update.version}.exe';
      final filePath = '${tempDir.path}\\$fileName';

      // Baixar arquivo com progresso
      await _dio.download(
        update.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onDownloadProgress?.call(progress);
          }
        },
      );

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Executa o instalador e fecha o aplicativo atual
  ///
  /// ATENÇÃO: Esta função fecha o aplicativo após executar o instalador.
  ///
  /// Exemplo:
  /// ```dart
  /// final filePath = await updateService.downloadUpdate(update);
  /// if (filePath != null) {
  ///   await updateService.installUpdate(filePath);
  /// }
  /// ```
  Future<void> installUpdate(String installerPath) async {
    try {
      // Verificar se o arquivo existe
      final file = File(installerPath);
      if (!await file.exists()) {
        return;
      }

      // Executar o instalador
      await Process.start(
        installerPath,
        [],
        mode: ProcessStartMode.detached,
      );

      // Aguardar um pouco para garantir que o instalador iniciou
      await Future.delayed(const Duration(seconds: 1));

      // Fechar o aplicativo
      exit(0);
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  /// Baixa e instala a atualização em um único passo
  ///
  /// Exemplo:
  /// ```dart
  /// final updateService = UpdateService();
  /// updateService.onDownloadProgress = (progress) {
  ///   print('Progresso: ${(progress * 100).toStringAsFixed(1)}%');
  /// };
  /// await updateService.downloadAndInstall(update);
  /// ```
  Future<void> downloadAndInstall(AppUpdate update) async {
    final filePath = await downloadUpdate(update);
    if (filePath != null) {
      await installUpdate(filePath);
    }
  }

  /// Limpa o cache de downloads antigos
  Future<void> cleanupOldDownloads() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file.path.contains('MyBusiness-Setup-') && file.path.endsWith('.exe')) {
          try {
            await file.delete();
          } catch (e) {
            // Falha ao remover arquivo
          }
        }
      }
    } catch (e) {
      // Falha ao limpar downloads antigos
    }
  }
}

