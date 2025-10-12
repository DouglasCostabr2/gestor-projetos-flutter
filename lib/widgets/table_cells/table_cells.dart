// Biblioteca de componentes reutilizáveis para células de tabelas
//
// Esta biblioteca fornece widgets padronizados para uso em cellBuilders
// de tabelas (DynamicPaginatedTable, ReusableDataTable, etc.)
//
// Benefícios:
// - Consistência visual em todas as tabelas
// - Manutenção centralizada
// - Performance otimizada (CachedAvatar)
// - Menos código duplicado
//
// Uso:
// ```dart
// import 'package:gestor_projetos_flutter/widgets/table_cells/table_cells.dart';
//
// // Em cellBuilders
// cellBuilders: [
//   (item) => TableCellAvatar(
//     avatarUrl: item['avatar_url'],
//     name: item['name'],
//   ),
//   (item) => TableCellDate(date: item['created_at']),
//   (item) => TableCellCurrency(valueCents: item['value_cents']),
//   (item) => TableCellCounter(count: item['total'], icon: Icons.task),
//   (item) => TableCellAvatarList(people: item['people']),
//   (item) => TableCellUpdatedBy(
//     date: item['updated_at'],
//     profile: item['updated_by_profile'],
//   ),
// ]
// ```

// Exportar todos os componentes
export 'table_cell_avatar.dart';
export 'table_cell_date.dart';
export 'table_cell_currency.dart';
export 'table_cell_counter.dart';
export 'table_cell_avatar_list.dart';
export 'table_cell_updated_by.dart';

