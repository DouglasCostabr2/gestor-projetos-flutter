import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../loaders/loaders.dart';

/// Widget para exibir avatares de rede
///
/// NOTA: Usa Image.network ao invés de CachedNetworkImage devido a problemas
/// de compatibilidade com Supabase Storage no Windows Desktop
///
/// Características:
/// - Placeholder durante carregamento
/// - Fallback para ícone se não houver URL ou em caso de erro
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

    // Usar Image.network ao invés de CachedNetworkImage
    // CachedNetworkImage tem problemas com Supabase Storage no Windows Desktop
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      foregroundColor: foregroundColor,
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            final progress = loadingProgress.cumulativeBytesLoaded;
            final total = loadingProgress.expectedTotalBytes ?? 0;
            return Center(
              child: CircularProgressIndicator(
                value: total > 0 ? progress / total : null,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              fallbackIcon,
              size: radius,
              color: foregroundColor ?? Colors.grey[600],
            );
          },
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
          : (context, url) => SkeletonLoader.box(
                width: width ?? 100,
                height: height ?? 100,
                borderRadius: 8,
              ),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
    );
  }
}

