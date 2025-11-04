import 'package:flutter/material.dart';
import '../../../../ui/atoms/inputs/inputs.dart';

/// Card para configurar uma plataforma de pagamento individual
/// 
/// Permite habilitar/desabilitar a plataforma e inserir o valor (email, ID, etc.)
class PaymentPlatformCard extends StatelessWidget {
  final String platformId;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final bool canEdit;
  final ValueChanged<bool>? onEnabledChanged;

  const PaymentPlatformCard({
    super.key,
    required this.platformId,
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    required this.canEdit,
    this.onEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled ? const Color(0xFF3D5AFE) : const Color(0xFF2A2A2A),
          width: enabled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com switch
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: canEdit ? onEnabledChanged : null,
                activeTrackColor: const Color(0xFF3D5AFE),
              ),
            ],
          ),
          
          if (enabled) ...[
            const SizedBox(height: 12),
            
            // Campo de texto
            GenericTextField(
              controller: controller,
              labelText: label,
              hintText: hint,
              enabled: canEdit,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ],
      ),
    );
  }
}

