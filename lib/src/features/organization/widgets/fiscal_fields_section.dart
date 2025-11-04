import 'package:flutter/material.dart';
import '../../../../ui/atoms/inputs/inputs.dart';
import '../models/country_fiscal_config.dart';
import '../services/fiscal_bank_data_service.dart';

/// Widget para exibir e editar campos fiscais
/// 
/// Renderiza campos fiscais baseados no país e tipo de pessoa selecionados
class FiscalFieldsSection extends StatelessWidget {
  final CountryFiscalConfig? countryConfig;
  final String? selectedCountryName;
  final String personType;
  final Map<String, TextEditingController> fiscalControllers;
  final bool canEdit;
  final bool saving;
  final FiscalBankDataService dataService;
  final String? selectedCountryCode;
  final ValueChanged<String>? onPersonTypeChanged;

  const FiscalFieldsSection({
    super.key,
    required this.countryConfig,
    required this.selectedCountryName,
    required this.personType,
    required this.fiscalControllers,
    required this.canEdit,
    required this.saving,
    required this.dataService,
    required this.selectedCountryCode,
    this.onPersonTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (countryConfig == null) {
      return const SizedBox.shrink();
    }

    final fiscalFields = countryConfig!.getFiscalFields(personType);
    if (fiscalFields.isEmpty) {
      return const SizedBox.shrink();
    }

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
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Dados Fiscais',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Informações fiscais e tributárias para ${selectedCountryName ?? 'o país selecionado'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Switch Pessoa Física / Pessoa Jurídica
          _buildPersonTypeSwitch(context),
          
          const SizedBox(height: 24),

          // Campos fiscais
          ...List.generate(fiscalFields.length, (index) {
            final field = fiscalFields[index];
            final controller = fiscalControllers[field.id]!;

            return Padding(
              padding: EdgeInsets.only(bottom: index < fiscalFields.length - 1 ? 16 : 0),
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

  Widget _buildPersonTypeSwitch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            personType == 'individual' ? Icons.person : Icons.business,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              personType == 'individual' ? 'Pessoa Física' : 'Pessoa Jurídica',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: personType == 'business',
              onChanged: canEdit && !saving
                  ? (value) {
                      final newPersonType = value ? 'business' : 'individual';
                      onPersonTypeChanged?.call(newPersonType);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

