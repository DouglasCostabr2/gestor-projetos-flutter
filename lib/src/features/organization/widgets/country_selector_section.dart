import 'package:flutter/material.dart';
import '../../../../ui/molecules/dropdowns/dropdowns.dart';

/// Widget para seleção de país
/// 
/// Exibe um dropdown com todos os países disponíveis
class CountrySelectorSection extends StatelessWidget {
  final String? selectedCountryCode;
  final List<Map<String, String>> countries;
  final bool canEdit;
  final bool saving;
  final ValueChanged<String?>? onCountrySelected;

  const CountrySelectorSection({
    super.key,
    required this.selectedCountryCode,
    required this.countries,
    required this.canEdit,
    required this.saving,
    this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Selecione o País',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Escolha o país onde sua organização está registrada. Os campos fiscais e bancários serão ajustados automaticamente.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          GenericDropdownField<String>(
            key: ValueKey('country_dropdown_$selectedCountryCode'),
            value: selectedCountryCode,
            items: countries.map((country) {
              return DropdownItem<String>(
                value: country['code']!,
                label: country['name']!,
              );
            }).toList(),
            onChanged: canEdit && !saving ? onCountrySelected : null,
            labelText: 'País da Organização',
            hintText: 'Selecione o país...',
            enabled: canEdit && !saving,
          ),
        ],
      ),
    );
  }
}

