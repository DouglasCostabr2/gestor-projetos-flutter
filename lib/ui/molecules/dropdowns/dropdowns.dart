/// Componentes dropdown genéricos reutilizáveis (Material 3 Design)
///
/// Este módulo fornece 2 tipos de dropdowns genéricos com design Material 3:
///
/// 1. **GenericDropdownField** - Dropdown simples com lista estática
///    - Use quando você tem uma lista fixa de opções
///    - Exemplo: status, prioridade, tipos predefinidos
///    - Design: Material 3 DropdownMenu
///
/// 2. **SearchableDropdownField** - Dropdown com busca integrada
///    - Use quando você tem muitas opções e precisa de busca
///    - Exemplo: categorias, países, cidades
///    - Design: Material 3 DropdownMenu com busca
///
/// Ambos os componentes usam o mesmo design do Material 3 (DropdownMenu)
/// para consistência visual em todo o aplicativo.
///
/// ## Exemplos de uso
///
/// ### GenericDropdownField
/// ```dart
/// GenericDropdownField<String>(
///   value: _status,
///   items: [
///     DropdownItem(value: 'active', label: 'Ativo'),
///     DropdownItem(value: 'inactive', label: 'Inativo'),
///   ],
///   onChanged: (value) => setState(() => _status = value),
///   labelText: 'Status',
///   width: 180, // Opcional: largura fixa
/// )
/// ```
///
/// ### SearchableDropdownField
/// ```dart
/// SearchableDropdownField<String>(
///   value: _category,
///   items: categories.map((cat) => SearchableDropdownItem(
///     value: cat['id'],
///     label: cat['name'],
///   )).toList(),
///   onChanged: (value) => setState(() => _category = value),
///   labelText: 'Categoria',
///   isLoading: _loadingCategories,
/// )
/// ```
library;

export 'generic_dropdown_field.dart';
export 'searchable_dropdown_field.dart';
export 'async_dropdown_field.dart';
export 'multi_select_dropdown_field.dart';

