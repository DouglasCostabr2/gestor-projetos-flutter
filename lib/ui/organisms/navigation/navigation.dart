/// Barrel file para Navigation (Organisms)
///
/// Exporta todos os componentes de navegação do tipo Organism.
///
/// ## Componentes:
/// - SideMenu - Menu lateral principal
/// - TabBarWidget - Barra de abas
///
/// ## Uso:
/// ```dart
/// import 'package:my_business/ui/organisms/navigation/navigation.dart';
/// 
/// // Usar componentes
/// SideMenu(
///   selectedIndex: selectedIndex,
///   onItemSelected: (index) { },
/// );
/// ```
library;

// Navigation
export 'side_menu.dart';
export 'menu_item_config.dart';
export 'tab_bar_widget.dart';

