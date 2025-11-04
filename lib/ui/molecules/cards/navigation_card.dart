import 'package:flutter/material.dart';

/// Card clicável para navegação com ícone, título e descrição
/// 
/// Componente genérico reutilizável que exibe um card com:
/// - Ícone em container arredondado
/// - Título em negrito
/// - Descrição em até 2 linhas
/// - Efeito hover e animação
/// - Conteúdo clipped nos cantos arredondados
/// 
/// Exemplo de uso:
/// ```dart
/// NavigationCard(
///   icon: Icons.settings,
///   title: 'Configurações',
///   description: 'Gerencie suas preferências',
///   onTap: () => Navigator.push(...),
/// )
/// ```
class NavigationCard extends StatefulWidget {
  /// Ícone exibido no topo do card
  final IconData icon;
  
  /// Título do card (1 linha, ellipsis se muito longo)
  final String title;
  
  /// Descrição do card (máximo 2 linhas, ellipsis se muito longo)
  final String description;
  
  /// Callback executado ao clicar no card
  final VoidCallback onTap;
  
  /// Cor de fundo do card (padrão: 0xFF1A1A1A)
  final Color? backgroundColor;
  
  /// Cor da borda do card (padrão: 0xFF2A2A2A)
  final Color? borderColor;
  
  /// Cor da borda ao fazer hover (padrão: 0xFF3A3A3A)
  final Color? hoverBorderColor;
  
  /// Cor de fundo do container do ícone (padrão: 0xFF2A2A2A)
  final Color? iconBackgroundColor;
  
  /// Cor do ícone (padrão: 0xFFEAEAEA)
  final Color? iconColor;
  
  /// Cor do título (padrão: 0xFFEAEAEA)
  final Color? titleColor;
  
  /// Cor da descrição (padrão: Colors.grey.shade500)
  final Color? descriptionColor;
  
  /// Tamanho do ícone (padrão: 24)
  final double iconSize;
  
  /// Border radius do card (padrão: 12)
  final double borderRadius;

  const NavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.iconBackgroundColor,
    this.iconColor,
    this.titleColor,
    this.descriptionColor,
    this.iconSize = 24,
    this.borderRadius = 12,
  });

  @override
  State<NavigationCard> createState() => _NavigationCardState();
}

class _NavigationCardState extends State<NavigationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Cores padrão
    final bgColor = widget.backgroundColor ?? const Color(0xFF1A1A1A);
    final borderColor = widget.borderColor ?? const Color(0xFF2A2A2A);
    final hoverBorderColor = widget.hoverBorderColor ?? const Color(0xFF3A3A3A);
    final iconBgColor = widget.iconBackgroundColor ?? const Color(0xFF2A2A2A);
    final iconColor = widget.iconColor ?? const Color(0xFFEAEAEA);
    final titleColor = widget.titleColor ?? const Color(0xFFEAEAEA);
    final descriptionColor = widget.descriptionColor ?? Colors.grey.shade500;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isHovered ? hoverBorderColor : borderColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Descrição
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: descriptionColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

