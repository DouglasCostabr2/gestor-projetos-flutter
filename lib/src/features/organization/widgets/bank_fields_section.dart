import 'package:flutter/material.dart';
import '../../../../ui/atoms/inputs/inputs.dart';
import '../models/country_fiscal_config.dart';

/// Widget para exibir e editar campos bancários
/// 
/// Renderiza campos bancários baseados no país selecionado
class BankFieldsSection extends StatelessWidget {
  final CountryFiscalConfig? countryConfig;
  final String? selectedCountryName;
  final Map<String, TextEditingController> bankControllers;
  final bool canEdit;
  final bool saving;

  const BankFieldsSection({
    super.key,
    required this.countryConfig,
    required this.selectedCountryName,
    required this.bankControllers,
    required this.canEdit,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    if (countryConfig == null || countryConfig!.bankFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Informações Bancárias',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dados bancários para ${selectedCountryName ?? 'o país selecionado'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(countryConfig!.bankFields.length, (index) {
            final field = countryConfig!.bankFields[index];
            final controller = bankControllers[field.id]!;

            return Padding(
              padding: EdgeInsets.only(bottom: index < countryConfig!.bankFields.length - 1 ? 16 : 0),
              child: GenericTextField(
                controller: controller,
                labelText: field.label,
                hintText: field.hint,
                enabled: canEdit && !saving,
                validator: field.validator,
              ),
            );
          }),
        ],
      ),
    );
  }
}

