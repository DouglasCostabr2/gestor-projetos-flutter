/// Modelo que representa uma atualização disponível do aplicativo
class AppUpdate {
  /// Versão da atualização (ex: "1.2.3")
  final String version;

  /// URL para download do instalador
  final String downloadUrl;

  /// Notas de lançamento em markdown
  final String? releaseNotes;

  /// Se true, a atualização é obrigatória
  final bool isMandatory;

  /// Versão mínima suportada
  final String? minSupportedVersion;

  /// Data de criação da versão
  final DateTime? createdAt;

  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
    this.isMandatory = false,
    this.minSupportedVersion,
    this.createdAt,
  });

  /// Cria uma instância de AppUpdate a partir de um Map (JSON do Supabase)
  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      version: json['version'] as String,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      minSupportedVersion: json['min_supported_version'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converte a instância para Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
      'is_mandatory': isMandatory,
      'min_supported_version': minSupportedVersion,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AppUpdate(version: $version, isMandatory: $isMandatory)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUpdate &&
        other.version == version &&
        other.downloadUrl == downloadUrl &&
        other.releaseNotes == releaseNotes &&
        other.isMandatory == isMandatory &&
        other.minSupportedVersion == minSupportedVersion;
  }

  @override
  int get hashCode {
    return version.hashCode ^
        downloadUrl.hashCode ^
        releaseNotes.hashCode ^
        isMandatory.hashCode ^
        minSupportedVersion.hashCode;
  }
}

