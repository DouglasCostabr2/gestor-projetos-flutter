import 'dart:io';
import 'package:flutter/foundation.dart';
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
    final startTime = DateTime.now();
    debugPrint('📁 [CacheService] Iniciando cópia: $sourcePath');

    final dirStart = DateTime.now();
    final dir = await getEditorCacheDir();
    final dirDuration = DateTime.now().difference(dirStart).inMilliseconds;
    debugPrint('📁 [CacheService] Diretório de cache obtido em ${dirDuration}ms: ${dir.path}');

    final ext = p.extension(sourcePath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${prefix}_$ts$ext';
    final destPath = p.join(dir.path, filename);

    // Para arquivos pequenos (<1MB), usar copy() direto é mais rápido
    final sourceFile = File(sourcePath);
    final sizeStart = DateTime.now();
    final fileSize = await sourceFile.length();
    final sizeDuration = DateTime.now().difference(sizeStart).inMilliseconds;
    final fileSizeMB = fileSize / 1024 / 1024;
    debugPrint('📁 [CacheService] Tamanho do arquivo: ${fileSizeMB.toStringAsFixed(2)} MB (obtido em ${sizeDuration}ms)');

    if (fileSize < 1024 * 1024) {
      // Arquivo pequeno: usar copy() nativo (mais rápido)
      debugPrint('📁 [CacheService] Usando copy() nativo (arquivo < 1MB)');
      final copyStart = DateTime.now();
      final result = await sourceFile.copy(destPath);
      final copyDuration = DateTime.now().difference(copyStart).inMilliseconds;
      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ [CacheService] Cópia concluída em ${copyDuration}ms (total: ${totalDuration}ms)');
      return result;
    }

    // Arquivo grande: usar streams para não bloquear a UI
    debugPrint('📁 [CacheService] Usando streams (arquivo >= 1MB)');
    final destFile = File(destPath);
    final sink = destFile.openWrite();
    try {
      final streamStart = DateTime.now();
      await sourceFile.openRead().pipe(sink);
      final streamDuration = DateTime.now().difference(streamStart).inMilliseconds;
      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ [CacheService] Cópia via stream concluída em ${streamDuration}ms (total: ${totalDuration}ms)');
      return destFile;
    } catch (e) {
      final errorDuration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('❌ [CacheService] Erro após ${errorDuration}ms: $e');
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

