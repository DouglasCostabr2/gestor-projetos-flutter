import 'package:flutter/material.dart';

/// Widget reutilizável para exibir uma linha de status de task
/// com contador e ação de clique
class TaskStatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final Color? countColor;
  final VoidCallback? onTap;

  const TaskStatusRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    this.countColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAction = count > 0 && onTap != null;

    return InkWell(
      onTap: hasAction ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: countColor,
                  ),
            ),
            SizedBox(
              width: 24,
              child: hasAction
                  ? Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

