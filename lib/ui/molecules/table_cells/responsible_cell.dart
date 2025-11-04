import 'package:flutter/material.dart';
import '../user_avatar_name.dart';
import 'table_cell_avatar_list.dart';

/// Widget reutilizável para células de tabela que exibem responsáveis
/// 
/// Aplica lógica condicional consistente:
/// - **1 responsável**: Mostra avatar + nome (UserAvatarName)
/// - **Múltiplos responsáveis**: Mostra apenas avatares (TableCellAvatarList)
/// - **Nenhum responsável**: Mostra "-"
/// 
/// Este widget garante consistência visual em todas as tabelas do sistema.
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas
/// (item) => ResponsibleCell(
///   people: item['assignees_list'],
/// )
/// 
/// // Com parâmetros customizados
/// (item) => ResponsibleCell(
///   people: item['task_assignees'],
///   maxVisible: 5,
///   emptyText: 'Sem responsável',
/// )
/// ```
class ResponsibleCell extends StatelessWidget {
  /// Lista de pessoas (cada item deve ter: id, full_name, email, avatar_url)
  final List<dynamic>? people;
  
  /// Tamanho do avatar quando há apenas 1 pessoa (diâmetro)
  final double singleAvatarSize;
  
  /// Tamanho do avatar quando há múltiplas pessoas (radius)
  final double multipleAvatarSize;
  
  /// Número máximo de avatares visíveis quando há múltiplas pessoas
  final int maxVisible;
  
  /// Texto a exibir quando lista está vazia
  final String emptyText;

  const ResponsibleCell({
    super.key,
    required this.people,
    this.singleAvatarSize = 20.0,
    this.multipleAvatarSize = 10.0,
    this.maxVisible = 3,
    this.emptyText = '-',
  });

  @override
  Widget build(BuildContext context) {
    final peopleList = people ?? [];
    
    // Nenhum responsável
    if (peopleList.isEmpty) {
      return Text(emptyText);
    }
    
    // Um único responsável - mostra avatar + nome
    if (peopleList.length == 1) {
      final person = peopleList[0] as Map<String, dynamic>;
      final fullName = person['full_name'] as String? ?? 
                       person['email'] as String? ?? 
                       emptyText;
      final avatarUrl = person['avatar_url'] as String?;
      
      return UserAvatarName(
        avatarUrl: avatarUrl,
        name: fullName,
        size: singleAvatarSize,
      );
    }
    
    // Múltiplos responsáveis - mostra apenas avatares
    return TableCellAvatarList(
      people: peopleList,
      maxVisible: maxVisible,
      avatarSize: multipleAvatarSize,
    );
  }
}

