import 'package:flutter/material.dart';

/// Componente base para skeleton loading com animação shimmer
/// 
/// Características:
/// - Animação shimmer suave (gradiente deslizante)
/// - Variações: box, circle, text
/// - Cores adaptadas ao tema dark
/// - Performance otimizada
/// 
/// Uso:
/// ```dart
/// // Box skeleton
/// SkeletonLoader.box(width: 100, height: 20)
/// 
/// // Circle skeleton (avatar)
/// SkeletonLoader.circle(size: 40)
/// 
/// // Text skeleton (linha de texto)
/// SkeletonLoader.text(width: 200)
/// ```
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 4,
    this.margin,
  });

  /// Cria um skeleton em formato de caixa (retângulo)
  const SkeletonLoader.box({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.margin,
  });

  /// Cria um skeleton em formato de círculo (avatar)
  const SkeletonLoader.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 999; // Círculo perfeito

  /// Cria um skeleton em formato de linha de texto
  const SkeletonLoader.text({
    super.key,
    required this.width,
    this.margin,
  })  : height = 14,
        borderRadius = 4;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surfaceContainerHigh;

    return Container(
      margin: widget.margin,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: baseColor,
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  baseColor,
                  highlightColor,
                  baseColor,
                ],
                stops: [
                  _animation.value - 0.3,
                  _animation.value,
                  _animation.value + 0.3,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton para linha de tabela
/// 
/// Uso:
/// ```dart
/// TableRowSkeleton(columnCount: 5)
/// ```
class TableRowSkeleton extends StatelessWidget {
  final int columnCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const TableRowSkeleton({
    super.key,
    required this.columnCount,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      child: Row(
        children: List.generate(
          columnCount,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SkeletonLoader.text(
                width: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton para card de informação
/// 
/// Uso:
/// ```dart
/// InfoCardSkeleton(itemCount: 4)
/// ```
class InfoCardSkeleton extends StatelessWidget {
  final int itemCount;
  final double minHeight;

  const InfoCardSkeleton({
    super.key,
    required this.itemCount,
    this.minHeight = 104,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 0,
          runSpacing: 24,
          children: List.generate(
            itemCount,
            (index) => SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label skeleton
                  SkeletonLoader.text(width: 80),
                  const SizedBox(height: 8),
                  // Content skeleton
                  SkeletonLoader.text(width: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton para avatar com nome
/// 
/// Uso:
/// ```dart
/// AvatarNameSkeleton(size: 40)
/// ```
class AvatarNameSkeleton extends StatelessWidget {
  final double size;
  final double nameWidth;

  const AvatarNameSkeleton({
    super.key,
    this.size = 40,
    this.nameWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonLoader.circle(size: size),
        const SizedBox(width: 8),
        SkeletonLoader.text(width: nameWidth),
      ],
    );
  }
}

/// Skeleton para lista de itens
///
/// Uso:
/// ```dart
/// ListSkeleton(itemCount: 5)
/// ```
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry itemPadding;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 60,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Container(
          height: itemHeight,
          padding: itemPadding,
          child: Row(
            children: [
              SkeletonLoader.circle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonLoader.text(width: double.infinity),
                    const SizedBox(height: 8),
                    SkeletonLoader.text(width: 150),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton para formulário
///
/// Uso:
/// ```dart
/// FormSkeleton(fieldCount: 6)
/// ```
class FormSkeleton extends StatelessWidget {
  final int fieldCount;
  final double fieldHeight;
  final double fieldSpacing;

  const FormSkeleton({
    super.key,
    this.fieldCount = 6,
    this.fieldHeight = 56,
    this.fieldSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        fieldCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: fieldSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label skeleton
              SkeletonLoader.text(width: 100),
              const SizedBox(height: 8),
              // Field skeleton
              SkeletonLoader.box(
                width: double.infinity,
                height: fieldHeight,
                borderRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

