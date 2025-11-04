/// Interface para o serviço de imagens de briefing
///
/// Define o contrato público para gerenciamento de imagens de briefing.
/// Permite desacoplamento e facilita testes com mocks.
///
/// ## Implementações:
/// - `BriefingImageService` - Implementação principal
/// - `MockBriefingImageService` - Mock para testes
///
/// ## Uso:
/// ```dart
/// final service = serviceLocator.get<IBriefingImageService>();
/// final updatedJson = await service.uploadCachedImages(
///   briefingJson: json,
///   clientName: 'Cliente ABC',
///   projectName: 'Projeto XYZ',
///   taskTitle: 'Tarefa 1',
/// );
/// ```
abstract class IBriefingImageService {
  /// Faz upload de imagens em cache para o Google Drive
  ///
  /// Processa o JSON do briefing, identifica imagens locais (file://),
  /// faz upload para o Google Drive e atualiza as URLs no JSON.
  ///
  /// Parâmetros:
  /// - [briefingJson]: JSON do briefing contendo blocos com imagens
  /// - [clientName]: Nome do cliente
  /// - [projectName]: Nome do projeto
  /// - [taskTitle]: Título da tarefa
  /// - [companyName]: Nome da empresa (opcional)
  /// - [subTaskTitle]: Título da subtarefa (opcional, se fornecido é subtarefa)
  ///
  /// Retorna: JSON atualizado com URLs do Google Drive
  ///
  /// Exemplo:
  /// ```dart
  /// final updatedJson = await service.uploadCachedImages(
  ///   briefingJson: '{"blocks":[{"type":"image","content":"file://..."}]}',
  ///   clientName: 'Cliente ABC',
  ///   projectName: 'Projeto XYZ',
  ///   taskTitle: 'Tarefa 1',
  /// );
  /// ```
  Future<String> uploadCachedImages({
    required String briefingJson,
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    String? subfolderName,
    String? filePrefix,
  });
}

