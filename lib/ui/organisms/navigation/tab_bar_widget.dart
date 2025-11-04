import 'package:flutter/material.dart';
import '../../../src/navigation/tab_item.dart';
import '../../../src/navigation/interfaces/tab_manager_interface.dart';

/// Widget da barra de abas
///
/// Usa a interface ITabManager para permitir desacoplamento e facilitar testes.
class TabBarWidget extends StatelessWidget {
  final ITabManager tabManager;
  final VoidCallback? onNewTab;

  const TabBarWidget({
    super.key,
    required this.tabManager,
    this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabManager,
      builder: (context, _) {
        if (tabManager.tabs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calcula a largura disponível (descontando o botão +)
              final availableWidth = constraints.maxWidth - 40; // 40px para o botão +
              final tabCount = tabManager.tabs.length;

              // Calcula a largura de cada aba
              // Máximo: 260px (mesma largura do side menu expandido), Mínimo: 120px
              double tabWidth = tabCount > 0
                  ? (availableWidth / tabCount).clamp(120.0, 260.0)
                  : 260.0;

              return Row(
                children: [
                  // Abas
                  ...List.generate(tabManager.tabs.length, (index) {
                    final tab = tabManager.tabs[index];
                    final isSelected = index == tabManager.currentIndex;
                    final hasMultipleTabs = tabManager.tabs.length > 1;

                    return _TabButton(
                      tab: tab,
                      isSelected: isSelected,
                      onTap: () => tabManager.selectTab(index),
                      onClose: (tab.canClose && hasMultipleTabs)
                          ? () => tabManager.removeTab(index)
                          : null,
                      onMiddleClick: (tab.canClose && hasMultipleTabs)
                          ? () => tabManager.removeTab(index)
                          : null,
                      width: tabWidth,
                    );
                  }),
                  // Botão + ao lado da última aba
                  if (onNewTab != null)
                    _NewTabButton(onPressed: onNewTab!),
                  // Espaço vazio até o final
                  const Spacer(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TabButton extends StatefulWidget {
  final TabItem tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final VoidCallback? onMiddleClick;
  final double width;

  const _TabButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    this.onClose,
    this.onMiddleClick,
    required this.width,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTertiaryTapUp: widget.onMiddleClick != null
            ? (_) => widget.onMiddleClick!()
            : null,
        child: Container(
          width: widget.width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF151515)
                : _isHovered
                    ? const Color(0xFF2A2A2A)
                    : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: const Border(
              right: BorderSide(color: Color(0xFF2A2A2A), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                widget.tab.icon,
                size: 16,
                color: widget.isSelected
                    ? const Color(0xFFEAEAEA)
                    : const Color(0xFF9AA0A6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.tab.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isSelected
                        ? const Color(0xFFEAEAEA)
                        : const Color(0xFF9AA0A6),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (widget.onClose != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: _isHovered
                          ? const Color(0xFFEAEAEA)
                          : const Color(0xFF9AA0A6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTabButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _NewTabButton({required this.onPressed});

  @override
  State<_NewTabButton> createState() => _NewTabButtonState();
}

class _NewTabButtonState extends State<_NewTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF2A2A2A)
                : Colors.transparent,
          ),
          child: const Icon(
            Icons.add,
            size: 18,
            color: Color(0xFF9AA0A6),
          ),
        ),
      ),
    );
  }
}

