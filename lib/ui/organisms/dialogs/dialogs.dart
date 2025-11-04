/// Barrel file para Dialogs (Organisms)
///
/// Exporta todos os componentes de diálogo do tipo Organism.
///
/// ## Componentes:
/// - StandardDialog - Diálogo padrão reutilizável
/// - DriveConnectDialog - Diálogo de conexão com Google Drive
/// - DialogHelper - Helper para exibir diálogos com backdrop escuro e desfocado
///
/// ## Uso:
/// ```dart
/// import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
///
/// // Usar componentes
/// DialogHelper.show(
///   context: context,
///   builder: (context) => StandardDialog(...),
/// );
/// ```
library;

// Dialogs
export 'standard_dialog.dart';
export 'drive_connect_dialog.dart';
export 'dialog_helper.dart';

