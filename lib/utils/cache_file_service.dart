import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// CacheFileService
/// - Centraliza a criação e uso de diretórios de cache do editor/briefing
/// - Garante nomes de arquivo únicos e remoção segura apenas de itens do cache
class CacheFileService {
  /// Retorna o diretório de cache dedicado do editor: {temp}/editor_images
  static Future<Directory> getEditorCacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'editor_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copia um arquivo de origem para o cache do editor com um nome único
  /// Mantém a extensão original.
  ///
  /// OTIMIZAÇÃO: Usa streams para copiar arquivos grandes sem bloquear a UI
  /// e sem carregar o arquivo inteiro na memória.
  static Future<File> copyToEditorCache(String sourcePath, {String prefix = 'Editor'}) async {

    final dir = await getEditorCacheDir();

    final ext = p.extension(sourcePath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${prefix}_$ts$ext';
    final destPath = p.join(dir.path, filename);

    // Para arquivos pequenos (<1MB), usar copy() direto é mais rápido
    final sourceFile = File(sourcePath);
    final fileSize = await sourceFile.length();

    if (fileSize < 1024 * 1024) {
      // Arquivo pequeno: usar copy() nativo (mais rápido)
      final result = await sourceFile.copy(destPath);
      return result;
    }

    // Arquivo grande: usar streams para não bloquear a UI
    final destFile = File(destPath);
    final sink = destFile.openWrite();
    try {
      await sourceFile.openRead().pipe(sink);
      return destFile;
    } catch (e) {
      // Limpar arquivo parcial em caso de erro
      if (await destFile.exists()) {
        await destFile.delete();
      }
      rethrow;
    }
  }

  /// Verifica se um caminho pertence ao cache da aplicação
  /// Compatível com caches antigos do briefing (briefing_images)
  static bool isInAppCachePath(String anyPath) {
    final norm = anyPath.replaceAll('\\', '/').toLowerCase();
    return norm.contains('/editor_images/') || norm.contains('/briefing_images/');
  }

  /// Deleta o arquivo se (e somente se) ele estiver no cache da aplicação
  static Future<void> deleteIfInAppCache(String anyPath) async {
    if (!isInAppCachePath(anyPath)) return;
    try {
      final f = File(anyPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // silencioso: falha ao apagar cache não deve quebrar o fluxo
    }
  }
}

