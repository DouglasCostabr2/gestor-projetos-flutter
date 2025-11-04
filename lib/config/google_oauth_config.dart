import 'package:googleapis/drive/v3.dart' as drive;

/// Configure Google OAuth 2.0 here.
/// For security, prefer to pass values via --dart-define.
/// Example run args:
///   --dart-define=GOOGLE_OAUTH_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=yyyy
class GoogleOAuthConfig {
  static const clientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    // Caso não passe via --dart-define, usa o valor abaixo
    defaultValue: '785385154853-mi7bsh7nbf5tgbufebv1k66qr67uph9u.apps.googleusercontent.com',
  );
  static const clientSecret = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_SECRET',
    // Caso não passe via --dart-define, usa o valor abaixo
    defaultValue: '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',
  );

  /// Scopes: create/upload files and read metadata + read user's email for status
  static const scopes = <String>[
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveMetadataScope,
    'https://www.googleapis.com/auth/userinfo.email',
  ];
}

