import 'package:flutter/material.dart';

class LinkedPreviewCard extends StatelessWidget {
  final String label;
  final String packageName;
  final String comment;
  final String thumbUrl;
  final VoidCallback? onClear;
  const LinkedPreviewCard({super.key, required this.label, required this.packageName, required this.comment, required this.thumbUrl, this.onClear});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        _SmallThumb(url: thumbUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              if (packageName.isNotEmpty)
                Text('Pacote: $packageName', style: theme.textTheme.bodySmall),
              if (comment.isNotEmpty)
                Text(comment, style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber)),
            ],
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 8),
          InkWell(onTap: onClear, child: const Icon(Icons.close, size: 18)),
        ],
      ]),
    );
  }
}

class _SmallThumb extends StatelessWidget {
  final String url;
  const _SmallThumb({required this.url});
  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2, size: 16),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

