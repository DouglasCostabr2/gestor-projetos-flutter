import 'package:flutter/material.dart';
import '../cached_avatar.dart';

/// Widget reutilizável para células de tabela com lista de avatares
/// 
/// Características:
/// - Mostra até N avatares visíveis
/// - Contador "+N" para avatares restantes
/// - Tooltip com nomes ao passar o mouse
/// - Remove duplicatas automaticamente
/// - Suporte a inicial ou ícone como fallback
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas
/// (item) => TableCellAvatarList(
///   people: item['task_people'],
///   maxVisible: 3,
/// )
/// 
/// // Com tamanho customizado
/// (item) => TableCellAvatarList(
///   people: item['assigned_users'],
///   maxVisible: 4,
///   avatarSize: 16,
/// )
/// ```
class TableCellAvatarList extends StatelessWidget {
  /// Lista de pessoas (cada item deve ter: id, full_name, avatar_url)
  final List<dynamic> people;
  
  /// Número máximo de avatares visíveis
  final int maxVisible;
  
  /// Tamanho de cada avatar (radius)
  final double avatarSize;
  
  /// Espaçamento entre avatares
  final double spacing;
  
  /// Se deve mostrar inicial quando não há avatar
  final bool showInitial;
  
  /// Texto a exibir quando lista está vazia
  final String emptyText;
  
  /// Cor de fundo do contador "+N"
  final Color? counterBackgroundColor;

  const TableCellAvatarList({
    super.key,
    required this.people,
    this.maxVisible = 3,
    this.avatarSize = 12.0,
    this.spacing = 4.0,
    this.showInitial = true,
    this.emptyText = '-',
    this.counterBackgroundColor,
  });

  /// Remove duplicatas baseado no ID
  List<Map<String, dynamic>> _getUniquePeople() {
    final uniqueMap = <String, Map<String, dynamic>>{};
    
    for (final person in people) {
      if (person is Map<String, dynamic>) {
        final id = person['id'] as String?;
        if (id != null && !uniqueMap.containsKey(id)) {
          uniqueMap[id] = person;
        }
      }
    }
    
    return uniqueMap.values.toList();
  }

  Widget _buildAvatar(Map<String, dynamic> person, BuildContext context) {
    final avatarUrl = person['avatar_url'] as String?;
    final fullName = person['full_name'] as String? ?? 'Sem nome';
    
    Widget avatar;
    
    if (showInitial && (avatarUrl == null || avatarUrl.isEmpty)) {
      avatar = CircleAvatar(
        radius: avatarSize,
        child: Text(
          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
          style: TextStyle(fontSize: avatarSize * 0.8),
        ),
      );
    } else {
      avatar = CachedAvatar(
        avatarUrl: avatarUrl,
        radius: avatarSize,
        fallbackIcon: Icons.person,
      );
    }
    
    return Tooltip(
      message: fullName,
      child: avatar,
    );
  }

  Widget _buildCounter(int remaining, BuildContext context) {
    final backgroundColor = counterBackgroundColor ?? Colors.grey[700];

    return Tooltip(
      message: '+$remaining pessoa${remaining > 1 ? 's' : ''}',
      child: CircleAvatar(
        radius: avatarSize,
        backgroundColor: backgroundColor,
        child: Text(
          '+$remaining',
          style: TextStyle(
            fontSize: avatarSize * 0.7,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniquePeople = _getUniquePeople();
    
    // Se lista está vazia
    if (uniquePeople.isEmpty) {
      return Text(emptyText);
    }
    
    // Pessoas a exibir (máximo maxVisible)
    final displayPeople = uniquePeople.take(maxVisible).toList();
    final remaining = uniquePeople.length - maxVisible;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatares
        ...displayPeople.asMap().entries.map((entry) {
          final index = entry.key;
          final person = entry.value;
          
          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? spacing : 0),
            child: _buildAvatar(person, context),
          );
        }),
        
        // Contador de pessoas restantes
        if (remaining > 0)
          Padding(
            padding: EdgeInsets.only(left: spacing),
            child: _buildCounter(remaining, context),
          ),
      ],
    );
  }
}

/// Variante simplificada que mostra apenas a contagem total
class TableCellPeopleCount extends StatelessWidget {
  final List<dynamic> people;
  final IconData icon;
  final double iconSize;
  final String emptyText;

  const TableCellPeopleCount({
    super.key,
    required this.people,
    this.icon = Icons.people,
    this.iconSize = 16.0,
    this.emptyText = '-',
  });

  int _getUniqueCount() {
    final uniqueIds = <String>{};
    
    for (final person in people) {
      if (person is Map<String, dynamic>) {
        final id = person['id'] as String?;
        if (id != null) {
          uniqueIds.add(id);
        }
      }
    }
    
    return uniqueIds.length;
  }

  @override
  Widget build(BuildContext context) {
    final count = _getUniqueCount();
    
    if (count == 0) {
      return Text(emptyText);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize),
        const SizedBox(width: 4),
        Text('$count'),
      ],
    );
  }
}

