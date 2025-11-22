import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../core/exceptions/app_exceptions.dart';
import '../../core/error_handler/error_handler.dart';

/// Modelo para arquivo enviado ao Google Drive
class UploadedFile {
  final String id;
  final String name;
  final String? publicViewUrl;

  UploadedFile({
    required this.id,
    required this.name,
    this.publicViewUrl,
  });
}

/// Serviço de upload de arquivos para o Google Drive
/// 
/// Responsável por:
/// - Upload de arquivos
/// - Configuração de permissões públicas
/// - Geração de URLs públicas
class GoogleDriveUploadService {
  /// Fazer upload de arquivo para o Google Drive
  /// 
  /// Envia um arquivo para uma pasta específica e configura permissões públicas.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta de destino
  /// - [filename]: Nome do arquivo
  /// - [bytes]: Conteúdo do arquivo em bytes
  /// - [mimeType]: Tipo MIME do arquivo (ex: 'image/jpeg')
  /// - [makePublic]: Se true, torna o arquivo público (padrão: true)
  /// 
  /// Retorna: Objeto UploadedFile com ID e URL pública
  /// 
  /// Exemplo:
  /// ```dart
  /// final uploaded = await uploadService.uploadFile(
  ///   client: client,
  ///   folderId: 'folder123',
  ///   filename: 'image.jpg',
  ///   bytes: imageBytes,
  ///   mimeType: 'image/jpeg',
  /// );
  /// print('URL pública: ${uploaded.publicViewUrl}');
  /// ```
  Future<UploadedFile> uploadFile({
    required http.Client client,
    required String folderId,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    bool makePublic = true,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);


      // Criar metadados do arquivo
      final driveFile = drive.File()
        ..name = filename
        ..parents = [folderId];

      // Criar media para upload
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      // Fazer upload
      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, webViewLink',
      );

      final fileId = uploadedFile.id!;

      // Tornar arquivo público se solicitado
      String? publicUrl;
      if (makePublic) {
        publicUrl = await _makeFilePublic(
          client: client,
          fileId: fileId,
        );
      }

      return UploadedFile(
        id: fileId,
        name: filename,
        publicViewUrl: publicUrl,
      );
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveUploadService.uploadFile',
      );
      
      throw DriveException(
        'Erro ao fazer upload do arquivo: $filename',
        originalError: e,
      );
    }
  }

  /// Tornar arquivo público
  /// 
  /// Configura permissões para que qualquer pessoa com o link possa visualizar.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [fileId]: ID do arquivo
  /// 
  /// Retorna: URL pública para visualização
  Future<String> _makeFilePublic({
    required http.Client client,
    required String fileId,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);


      // Criar permissão pública
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';

      await driveApi.permissions.create(
        permission,
        fileId,
      );

      // Gerar URL pública
      final publicUrl = 'https://drive.google.com/uc?export=view&id=$fileId';
      
      return publicUrl;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveUploadService._makeFilePublic',
      );
      
      throw DriveException(
        'Erro ao tornar arquivo público',
        originalError: e,
      );
    }
  }

  /// Upload de múltiplos arquivos
  /// 
  /// Faz upload de vários arquivos para a mesma pasta.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta de destino
  /// - [files]: Lista de arquivos (Map com 'filename', 'bytes', 'mimeType')
  /// - [makePublic]: Se true, torna os arquivos públicos (padrão: true)
  /// 
  /// Retorna: Lista de arquivos enviados
  /// 
  /// Exemplo:
  /// ```dart
  /// final files = [
  ///   {'filename': 'img1.jpg', 'bytes': bytes1, 'mimeType': 'image/jpeg'},
  ///   {'filename': 'img2.jpg', 'bytes': bytes2, 'mimeType': 'image/jpeg'},
  /// ];
  /// final uploaded = await uploadService.uploadMultipleFiles(
  ///   client: client,
  ///   folderId: 'folder123',
  ///   files: files,
  /// );
  /// ```
  Future<List<UploadedFile>> uploadMultipleFiles({
    required http.Client client,
    required String folderId,
    required List<Map<String, dynamic>> files,
    bool makePublic = true,
  }) async {
    try {

      final uploadedFiles = <UploadedFile>[];

      for (final fileData in files) {
        final uploaded = await uploadFile(
          client: client,
          folderId: folderId,
          filename: fileData['filename'] as String,
          bytes: fileData['bytes'] as Uint8List,
          mimeType: fileData['mimeType'] as String,
          makePublic: makePublic,
        );

        uploadedFiles.add(uploaded);
      }

      return uploadedFiles;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveUploadService.uploadMultipleFiles',
      );
      
      throw DriveException(
        'Erro ao fazer upload de múltiplos arquivos',
        originalError: e,
      );
    }
  }

  /// Substituir arquivo existente
  /// 
  /// Atualiza o conteúdo de um arquivo existente mantendo o mesmo ID.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [fileId]: ID do arquivo a ser substituído
  /// - [bytes]: Novo conteúdo do arquivo
  /// - [mimeType]: Tipo MIME do arquivo
  /// 
  /// Exemplo:
  /// ```dart
  /// await uploadService.replaceFile(
  ///   client: client,
  ///   fileId: 'file123',
  ///   bytes: newBytes,
  ///   mimeType: 'image/jpeg',
  /// );
  /// ```
  Future<void> replaceFile({
    required http.Client client,
    required String fileId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);


      // Criar media para upload
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      // Atualizar arquivo
      await driveApi.files.update(
        drive.File(),
        fileId,
        uploadMedia: media,
      );

    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveUploadService.replaceFile',
      );
      
      throw DriveException(
        'Erro ao substituir arquivo',
        originalError: e,
      );
    }
  }

  /// Verificar se arquivo existe antes de fazer upload
  /// 
  /// Verifica se já existe um arquivo com o mesmo nome na pasta.
  /// Se existir, pode substituir ou criar com nome diferente.
  /// 
  /// Parâmetros:
  /// - [client]: Cliente HTTP autenticado
  /// - [folderId]: ID da pasta
  /// - [filename]: Nome do arquivo
  /// 
  /// Retorna: ID do arquivo se existir, null caso contrário
  Future<String?> checkFileExists({
    required http.Client client,
    required String folderId,
    required String filename,
  }) async {
    try {
      final driveApi = drive.DriveApi(client);

      final query = "name='$filename' and '$folderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      return null;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveUploadService.checkFileExists',
      );
      return null;
    }
  }
}

