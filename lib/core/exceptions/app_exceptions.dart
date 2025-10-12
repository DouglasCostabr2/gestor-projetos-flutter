/// Exceções customizadas da aplicação
///
/// Todas as exceções do app devem herdar de AppException
/// para facilitar o tratamento centralizado de erros
library;

/// Exceção base da aplicação
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AppException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (originalError != null) buffer.write('\nOriginal error: $originalError');
    return buffer.toString();
  }
}

/// Exceção de autenticação
class AuthException extends AppException {
  AuthException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de rede/conectividade
class NetworkException extends AppException {
  NetworkException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de validação de dados
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(
    super.message, {
    super.code,
    this.fieldErrors,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de permissão/autorização
class PermissionException extends AppException {
  PermissionException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de recurso não encontrado
class NotFoundException extends AppException {
  final String? resourceType;
  final String? resourceId;

  NotFoundException(
    super.message, {
    super.code,
    this.resourceType,
    this.resourceId,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de operação de arquivo/storage
class StorageException extends AppException {
  StorageException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de operação no Google Drive
class DriveException extends AppException {
  DriveException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de operação no banco de dados
class DatabaseException extends AppException {
  DatabaseException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de operação de negócio
class BusinessException extends AppException {
  BusinessException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de timeout
class TimeoutException extends AppException {
  final Duration? timeout;

  TimeoutException(
    super.message, {
    super.code,
    this.timeout,
    super.originalError,
    super.stackTrace,
  });
}

/// Exceção de conflito (ex: recurso já existe)
class ConflictException extends AppException {
  ConflictException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

