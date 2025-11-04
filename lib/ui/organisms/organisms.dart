// Atomic Design - ORGANISMS
//
// Componentes complexos que formam seções distintas de uma interface.
// Organismos combinam moléculas e/ou átomos para criar componentes
// relativamente complexos.
//
// Exemplos: header, sidebar, formulário completo, tabela de dados
//
// Categorias:
// - Dialogs - Diálogos e modais (StandardDialog, DriveConnectDialog)
// - Lists - Listas complexas (ReorderableDragList)
// - Tabs - Componentes de abas (GenericTabView)
// - Tables - Tabelas de dados (ReusableDataTable, DynamicPaginatedTable, TableSearchFilterBar)
// - Editors - Editores de texto (CustomBriefingEditor, ChatBriefing, TextFieldWithToolbar, AppFlowyTextFieldWithToolbar)
// - Sections - Seções de página (CommentsSection, TaskFilesSection, FinalProjectSection)
// - Navigation - Navegação (SideMenu, TabBarWidget)

// Exportar todas as categorias de organisms
export 'dialogs/dialogs.dart';
export 'lists/lists.dart';
export 'tabs/tabs.dart';
export 'tables/tables.dart';
export 'editors/editors.dart';
export 'sections/sections.dart';
export 'navigation/navigation.dart';

