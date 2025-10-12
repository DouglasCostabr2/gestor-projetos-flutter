import 'package:flutter/material.dart';
import 'cached_avatar.dart';

/// Widget reutilizável para exibir avatar + nome do usuário
///
/// Características:
/// - Exibe CircleAvatar com foto do usuário ou ícone padrão
/// - Exibe nome completo ou email como fallback
/// - Tamanho configurável do avatar
/// - Pode exibir apenas avatar ou avatar + nome
/// - OTIMIZAÇÃO: Usa CachedAvatar para cache automático
///
/// Uso:
/// ```dart
/// // Com nome
/// UserAvatarName(
///   avatarUrl: user['avatar_url'],
///   name: user['full_name'] ?? user['email'],
///   size: 20,
/// )
///
/// // Apenas avatar
/// UserAvatarName(
///   avatarUrl: user['avatar_url'],
///   name: user['full_name'],
///   size: 16,
///   showName: false,
/// )
/// ```
class UserAvatarName extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final bool showName;
  final TextStyle? nameStyle;

  const UserAvatarName({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 20,
    this.showName = true,
    this.nameStyle,
  });

  @override
  Widget build(BuildContext context) {
    // OTIMIZAÇÃO: Usar CachedAvatar em vez de CircleAvatar com NetworkImage
    final avatar = CachedAvatar(
      avatarUrl: avatarUrl,
      radius: size / 2,
      fallbackIcon: Icons.person,
    );

    if (!showName) {
      return avatar;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        SizedBox(width: size / 3),
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

/// Widget para usar em DropdownMenuItem com avatar + nome
/// OTIMIZAÇÃO: Usa CachedAvatar para cache automático
class UserDropdownItem extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double avatarSize;

  const UserDropdownItem({
    super.key,
    this.avatarUrl,
    required this.name,
    this.avatarSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CachedAvatar(
          avatarUrl: avatarUrl,
          radius: avatarSize / 2,
          fallbackIcon: Icons.person,
        ),
        SizedBox(width: avatarSize / 2),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

