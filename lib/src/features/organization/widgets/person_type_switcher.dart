import 'package:flutter/material.dart';

/// Widget para alternar entre Pessoa Física e Pessoa Jurídica
/// 
/// Exibe um switch estilizado com labels claros
class PersonTypeSwitcher extends StatelessWidget {
  final String personType;
  final bool canEdit;
  final ValueChanged<bool>? onChanged;

  const PersonTypeSwitcher({
    super.key,
    required this.personType,
    required this.canEdit,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBusiness = personType == 'business';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isBusiness ? Icons.business : Icons.person,
              color: const Color(0xFF3D5AFE),
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipo de Pessoa',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBusiness ? 'Pessoa Jurídica' : 'Pessoa Física',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Switch
          Switch(
            value: isBusiness,
            onChanged: canEdit ? onChanged : null,
            activeTrackColor: const Color(0xFF3D5AFE),
            inactiveThumbColor: const Color(0xFF9E9E9E),
            inactiveTrackColor: const Color(0xFF424242),
          ),
        ],
      ),
    );
  }
}

