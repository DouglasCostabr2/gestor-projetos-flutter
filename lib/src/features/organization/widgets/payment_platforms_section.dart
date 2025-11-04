import 'package:flutter/material.dart';
import '../../../../ui/atoms/inputs/inputs.dart';

/// Widget para exibir e editar plataformas de pagamento
/// 
/// Renderiza campos para plataformas de pagamento online (PayPal, Stripe, etc.)
class PaymentPlatformsSection extends StatelessWidget {
  final List<Map<String, String>> paymentPlatforms;
  final Map<String, TextEditingController> paymentPlatformControllers;
  final Map<String, bool> paymentPlatformEnabled;
  final bool canEdit;
  final bool saving;
  final ValueChanged<MapEntry<String, bool>>? onPlatformEnabledChanged;

  const PaymentPlatformsSection({
    super.key,
    required this.paymentPlatforms,
    required this.paymentPlatformControllers,
    required this.paymentPlatformEnabled,
    required this.canEdit,
    required this.saving,
    this.onPlatformEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment,
                color: Theme.of(context).colorScheme.tertiary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Plataformas de Pagamento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Informações de contas em plataformas de pagamento online',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          ...List.generate(paymentPlatforms.length, (index) {
            final platform = paymentPlatforms[index];
            final platformId = platform['id']!;
            final controller = paymentPlatformControllers[platformId]!;
            final isEnabled = paymentPlatformEnabled[platformId] ?? false;

            return Padding(
              padding: EdgeInsets.only(bottom: index < paymentPlatforms.length - 1 ? 16 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de texto
                  Expanded(
                    child: GenericTextField(
                      controller: controller,
                      labelText: platform['label']!,
                      hintText: platform['hint']!,
                      enabled: canEdit && !saving && isEnabled,
                      maxLines: platformId == 'other_platform' ? 3 : 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Switch ao lado
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isEnabled,
                        onChanged: canEdit && !saving
                            ? (value) {
                                onPlatformEnabledChanged?.call(
                                  MapEntry(platformId, value),
                                );
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

