import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../core/exceptions/app_exceptions.dart';
import '../../core/error_handler/error_handler.dart';

/// Serviço de gerenciamento de arquivos do Google Drive
/// 
/// Responsável por:
/// - Deletar arquivos
/// - Renomear arquivos
/// - Buscar arquivos
/// - Mover arquivos entre pastas
class GoogleDriveFileService {
  /// Deletar arquivo do Google Drive
  /// 
  /// Remove permanentemente um arquivo do Google Drive.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [driveFileId]: ID do arquivo a ser deletado
  /// 
  /// Exemplo:
  /// ```dart
  /// await fileService.deleteFile(
  ///   client: client,
  ///   driveFileId: 'abc123xyz',
  /// );
  /// ```
  Future<void> deleteFile({
    required http.Client client,
    required String driveFileId,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('🗑️ Deletando arquivo: $driveFileId');

      await driveApi.files.delete(driveFileId);

      debugPrint('✅ Arquivo deletado com sucesso');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.deleteFile',
      );
      
      throw DriveException(
        'Erro ao deletar arquivo do Google Drive',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Renomear arquivo no Google Drive
  /// 
  /// Altera o nome de um arquivo existente.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [fileId]: ID do arquivo a ser renomeado
  /// - [newName]: Novo nome do arquivo
  /// 
  /// Exemplo:
  /// ```dart
  /// await fileService.renameFile(
  ///   client: client,
  ///   fileId: 'abc123',
  ///   newName: 'novo-nome.jpg',
  /// );
  /// ```
  Future<void> renameFile({
    required http.Client client,
    required String fileId,
    required String newName,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('✏️ Renomeando arquivo $fileId para: $newName');

      final file = drive.File()..name = newName;
      
      await driveApi.files.update(
        file,
        fileId,
        $fields: 'id, name',
      );

      debugPrint('✅ Arquivo renomeado com sucesso');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.renameFile',
      );
      
      throw DriveException(
        'Erro ao renomear arquivo',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Buscar arquivos em uma pasta
  /// 
  /// Lista todos os arquivos dentro de uma pasta específica.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta
  /// - [namePattern]: Padrão de nome para filtrar (opcional)
  /// 
  /// Retorna: Lista de arquivos encontrados
  /// 
  /// Exemplo:
  /// ```dart
  /// final files = await fileService.listFilesInFolder(
  ///   client: client,
  ///   folderId: 'folder123',
  ///   namePattern: 'Briefing-',
  /// );
  /// ```
  Future<List<drive.File>> listFilesInFolder({
    required http.Client client,
    required String folderId,
    String? namePattern,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('📂 Listando arquivos na pasta: $folderId');

      String query = "'$folderId' in parents and trashed=false";
      if (namePattern != null) {
        query += " and name contains '$namePattern'";
      }

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, createdTime, modifiedTime, size)',
      );

      final files = fileList.files ?? [];
      debugPrint('✅ Encontrados ${files.length} arquivos');
      
      return files;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.listFilesInFolder',
      );
      
      throw DriveException(
        'Erro ao listar arquivos',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Mover arquivo para outra pasta
  /// 
  /// Move um arquivo de uma pasta para outra.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [fileId]: ID do arquivo a ser movido
  /// - [currentParentId]: ID da pasta atual
  /// - [newParentId]: ID da nova pasta
  /// 
  /// Exemplo:
  /// ```dart
  /// await fileService.moveFile(
  ///   client: client,
  ///   fileId: 'file123',
  ///   currentParentId: 'oldFolder',
  ///   newParentId: 'newFolder',
  /// );
  /// ```
  Future<void> moveFile({
    required http.Client client,
    required String fileId,
    required String currentParentId,
    required String newParentId,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('📦 Movendo arquivo $fileId de $currentParentId para $newParentId');

      await driveApi.files.update(
        drive.File(),
        fileId,
        addParents: newParentId,
        removeParents: currentParentId,
        $fields: 'id, parents',
      );

      debugPrint('✅ Arquivo movido com sucesso');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.moveFile',
      );
      
      throw DriveException(
        'Erro ao mover arquivo',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Buscar arquivo por nome em uma pasta
  /// 
  /// Procura um arquivo específico dentro de uma pasta.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta
  /// - [fileName]: Nome exato do arquivo
  /// 
  /// Retorna: ID do arquivo ou null se não encontrado
  /// 
  /// Exemplo:
  /// ```dart
  /// final fileId = await fileService.findFileByName(
  ///   client: client,
  ///   folderId: 'folder123',
  ///   fileName: 'image.jpg',
  /// );
  /// ```
  Future<String?> findFileByName({
    required http.Client client,
    required String folderId,
    required String fileName,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('🔍 Buscando arquivo: $fileName em $folderId');

      final query = "name='$fileName' and '$folderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        debugPrint('✅ Arquivo encontrado: $fileId');
        return fileId;
      }

      debugPrint('⚠️ Arquivo não encontrado');
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.findFileByName',
      );
      return null;
    }
  }

  /// Obter metadados de um arquivo
  /// 
  /// Retorna informações detalhadas sobre um arquivo.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [fileId]: ID do arquivo
  /// 
  /// Retorna: Objeto File com metadados
  Future<drive.File?> getFileMetadata({
    required http.Client client,
    required String fileId,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('📄 Buscando metadados do arquivo: $fileId');

      final file = await driveApi.files.get(
        fileId,
        $fields: 'id, name, mimeType, size, createdTime, modifiedTime, parents, webViewLink',
      ) as drive.File;

      debugPrint('✅ Metadados obtidos');
      return file;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFileService.getFileMetadata',
      );
      return null;
    }
  }
}

