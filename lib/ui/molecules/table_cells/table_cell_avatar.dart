import 'package:flutter/material.dart';
import '../../atoms/avatars/cached_avatar.dart';

/// Widget reutilizável para células de tabela com avatar + nome
/// 
/// Características:
/// - Usa CachedAvatar para performance
/// - Tamanho configurável
/// - Suporte a inicial do nome ou ícone como fallback
/// - Layout horizontal com espaçamento consistente
/// - Overflow com ellipsis
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas
/// (item) => TableCellAvatar(
///   avatarUrl: item['avatar_url'],
///   name: item['name'],
///   size: 24,
/// )
/// 
/// // Com inicial como fallback
/// (item) => TableCellAvatar(
///   avatarUrl: item['avatar_url'],
///   name: item['name'],
///   size: 24,
///   showInitial: true,
/// )
/// ```
class TableCellAvatar extends StatelessWidget {
  /// URL do avatar (pode ser null)
  final String? avatarUrl;
  
  /// Nome a ser exibido
  final String name;
  
  /// Tamanho do avatar (diâmetro total = size * 2)
  final double size;
  
  /// Se deve mostrar inicial do nome quando não há avatar
  final bool showInitial;
  
  /// Ícone de fallback quando não há avatar e showInitial = false
  final IconData fallbackIcon;
  
  /// Estilo do texto do nome
  final TextStyle? nameStyle;
  
  /// Espaçamento entre avatar e nome
  final double spacing;

  const TableCellAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 12.0,
    this.showInitial = true,
    this.fallbackIcon = Icons.person,
    this.nameStyle,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    // Se não há avatar e deve mostrar inicial
    final shouldShowInitial = showInitial && (avatarUrl == null || avatarUrl!.isEmpty);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        if (shouldShowInitial)
          CircleAvatar(
            radius: size,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: size * 0.8),
            ),
          )
        else
          CachedAvatar(
            avatarUrl: avatarUrl,
            radius: size,
            fallbackIcon: fallbackIcon,
          ),

        SizedBox(width: spacing),

        // Nome
        Flexible(
          child: Text(
            name,
            style: nameStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Variante simplificada que mostra apenas o avatar (sem nome)
class TableCellAvatarOnly extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final bool showInitial;
  final IconData fallbackIcon;

  const TableCellAvatarOnly({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 12.0,
    this.showInitial = true,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShowInitial = showInitial && (avatarUrl == null || avatarUrl!.isEmpty);

    if (shouldShowInitial) {
      // Tooltip desabilitado para evitar erro de múltiplos tickers
      return CircleAvatar(
        radius: size,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: size * 0.8),
        ),
      );
    }

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    return CachedAvatar(
      avatarUrl: avatarUrl,
      radius: size,
      fallbackIcon: fallbackIcon,
    );
  }
}

