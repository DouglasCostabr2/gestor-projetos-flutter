import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../core/exceptions/app_exceptions.dart';
import '../../core/error_handler/error_handler.dart';

/// Serviço de gerenciamento de pastas do Google Drive
/// 
/// Responsável por:
/// - Criar pastas e subpastas
/// - Buscar pastas por nome
/// - Renomear pastas
/// - Deletar pastas
class GoogleDriveFolderService {
  /// Buscar ou criar pasta raiz "Gestor de Projetos"
  /// 
  /// Retorna o ID da pasta raiz. Se não existir, cria uma nova.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// 
  /// Retorna: ID da pasta raiz
  Future<String> getOrCreateRootFolder(http.Client client) async {
    try {
      final driveApi = drive.DriveApi(client);
      const folderName = 'Gestor de Projetos';

      debugPrint('📁 Buscando pasta raiz: $folderName');

      // Buscar pasta existente
      final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final folderId = fileList.files!.first.id!;
        debugPrint('✅ Pasta raiz encontrada: $folderId');
        return folderId;
      }

      // Criar nova pasta
      debugPrint('📁 Criando pasta raiz: $folderName');
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folder);
      final folderId = createdFolder.id!;
      
      debugPrint('✅ Pasta raiz criada: $folderId');
      return folderId;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFolderService.getOrCreateRootFolder',
      );
      
      throw DriveException(
        'Erro ao buscar/criar pasta raiz',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Buscar ou criar subpasta
  /// 
  /// Busca uma subpasta dentro de uma pasta pai. Se não existir, cria uma nova.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [parentFolderId]: ID da pasta pai
  /// - [folderName]: Nome da subpasta
  /// 
  /// Retorna: ID da subpasta
  Future<String> getOrCreateSubfolder({
    required http.Client client,
    required String parentFolderId,
    required String folderName,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('📁 Buscando subpasta: $folderName em $parentFolderId');

      // Buscar subpasta existente
      final query = "name='$folderName' and '$parentFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final folderId = fileList.files!.first.id!;
        debugPrint('✅ Subpasta encontrada: $folderId');
        return folderId;
      }

      // Criar nova subpasta
      debugPrint('📁 Criando subpasta: $folderName');
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentFolderId];

      final createdFolder = await driveApi.files.create(folder);
      final folderId = createdFolder.id!;
      
      debugPrint('✅ Subpasta criada: $folderId');
      return folderId;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFolderService.getOrCreateSubfolder',
      );
      
      throw DriveException(
        'Erro ao buscar/criar subpasta: $folderName',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Renomear pasta
  /// 
  /// Altera o nome de uma pasta existente no Google Drive.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta a ser renomeada
  /// - [newName]: Novo nome da pasta
  Future<void> renameFolder({
    required http.Client client,
    required String folderId,
    required String newName,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('✏️ Renomeando pasta $folderId para: $newName');

      final file = drive.File()..name = newName;
      
      await driveApi.files.update(
        file,
        folderId,
        $fields: 'id, name',
      );

      debugPrint('✅ Pasta renomeada com sucesso');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFolderService.renameFolder',
      );
      
      throw DriveException(
        'Erro ao renomear pasta',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletar pasta
  /// 
  /// Remove permanentemente uma pasta do Google Drive.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta a ser deletada
  Future<void> deleteFolder({
    required http.Client client,
    required String folderId,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('🗑️ Deletando pasta: $folderId');

      await driveApi.files.delete(folderId);

      debugPrint('✅ Pasta deletada com sucesso');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFolderService.deleteFolder',
      );
      
      throw DriveException(
        'Erro ao deletar pasta',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Buscar ID de pasta por nome e pasta pai
  /// 
  /// Busca uma pasta específica dentro de uma pasta pai.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [parentFolderId]: ID da pasta pai
  /// - [folderName]: Nome da pasta a buscar
  /// 
  /// Retorna: ID da pasta ou null se não encontrada
  Future<String?> findFolderByName({
    required http.Client client,
    required String parentFolderId,
    required String folderName,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      debugPrint('🔍 Buscando pasta: $folderName em $parentFolderId');

      final query = "name='$folderName' and '$parentFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final folderId = fileList.files!.first.id!;
        debugPrint('✅ Pasta encontrada: $folderId');
        return folderId;
      }

      debugPrint('⚠️ Pasta não encontrada');
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        context: 'GoogleDriveFolderService.findFolderByName',
      );
      return null;
    }
  }
}

