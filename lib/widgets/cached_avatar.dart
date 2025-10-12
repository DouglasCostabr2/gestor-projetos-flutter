import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget otimizado para exibir avatares com cache
/// 
/// OTIMIZAÇÃO: Usa cached_network_image para evitar downloads repetidos
/// 
/// Características:
/// - Cache automático em disco e memória
/// - Placeholder durante carregamento
/// - Fallback para ícone se não houver URL
/// - Suporta CircleAvatar e outros shapes
class CachedAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CachedAvatar({
    super.key,
    this.avatarUrl,
    required this.radius,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Se não há URL, mostrar ícone
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        child: Icon(fallbackIcon, size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Icon(
            fallbackIcon,
            size: radius,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}

/// Widget otimizado para exibir imagens com cache (não circular)
/// 
/// OTIMIZAÇÃO: Usa cached_network_image para thumbnails e outras imagens
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
    );
  }
}

