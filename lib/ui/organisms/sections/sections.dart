/// Barrel file para Sections (Organisms)
///
/// Exporta todos os componentes de seção do tipo Organism.
///
/// ## Componentes:
/// - CommentsSection - Seção de comentários
/// - TaskFilesSection - Seção de arquivos de tarefa
/// - FinalProjectSection - Seção de projeto final
///
/// ## Uso:
/// ```dart
/// import 'package:my_business/ui/organisms/sections/sections.dart';
/// 
/// // Usar componentes
/// CommentsSection(
///   taskId: taskId,
///   onCommentAdded: () { },
/// );
/// ```
library;

// Sections
export 'comments_section.dart';
export 'task_files_section.dart';
export 'final_project_section.dart';

