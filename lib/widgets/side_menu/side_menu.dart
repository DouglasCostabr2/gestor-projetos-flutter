import 'package:flutter/material.dart';
import '../../src/navigation/user_role.dart';
import 'menu_item_config.dart';
import '../cached_avatar.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

/// Widget do menu lateral da aplicação
class SideMenu extends StatefulWidget {
  final bool collapsed;
  final int selectedIndex;
  final void Function(int) onSelect;
  final VoidCallback onToggle;
  final VoidCallback onLogout;
  final VoidCallback? onProfileTap;
  final UserRole userRole;
  final Map<String, dynamic>? profile;

  const SideMenu({
    super.key,
    required this.collapsed,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggle,
    required this.onLogout,
    this.onProfileTap,
    required this.userRole,
    this.profile,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Define estado inicial
    if (widget.collapsed) {
      _controller.value = 0.0;
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      if (widget.collapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed palette to match the reference side menu design
    const cardColor = Color(0xFF151515);
    const onCard = Color(0xFFEAEAEA);
    const onMuted = Color(0xFF9AA0A6);
    const borderColor = Color(0xFF2A2A2A);
    const dividerColor = Color(0xFF2A2A2A);
    const selectedFill = Color(0x1AFFFFFF); // 10% white overlay
    const errorRed = Color(0xFFFF4D4D);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calcula largura baseada na animação
        final width = 72 + (_animation.value * (260 - 72));
        // Considera narrow quando animação está abaixo de 0.1 (muda bem cedo)
        final isNarrow = _animation.value < 0.1;

        return Container(
          width: width,
          color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Header com toggle
              SizedBox(
                height: 60,
                child: isNarrow
                    ? Center(
                        child: IconOnlyButton(
                          icon: Icons.chevron_right,
                          onPressed: widget.onToggle,
                          tooltip: 'Expandir',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Text(
                              'Menu',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            IconOnlyButton(
                              icon: Icons.chevron_left,
                              onPressed: widget.onToggle,
                              tooltip: 'Recolher',
                            ),
                          ],
                        ),
                      ),
              ),
              if (!isNarrow) const Divider(height: 1, color: dividerColor),

              // Perfil
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 0 : 16,
                  16,
                  isNarrow ? 0 : 16,
                  8,
                ),
                child: InkWell(
                  onTap: widget.onProfileTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(isNarrow ? 0 : 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: isNarrow
                      ? Center(
                          // OTIMIZAÇÃO: Usar CachedAvatar
                          child: CachedAvatar(
                            avatarUrl: widget.profile?['avatar_url'] as String?,
                            radius: 20,
                            fallbackIcon: Icons.person,
                          ),
                        )
                      : Row(
                          children: [
                            // OTIMIZAÇÃO: Usar CachedAvatar
                            CachedAvatar(
                              avatarUrl: widget.profile?['avatar_url'] as String?,
                              radius: 20,
                              fallbackIcon: Icons.person,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (widget.profile?['full_name'] ?? 'Usuário') as String,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: onCard,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.userRole.label,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: onMuted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
              if (!isNarrow)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 24),
                ),

              // Navegação
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: MenuConfig.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final config = MenuConfig.items[index];
                    final selected = index == widget.selectedIndex;
                    final hasAccess = config.isAccessibleBy(widget.userRole);

                    final tile = InkWell(
                      onTap: hasAccess ? () => widget.onSelect(index) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 0 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? selectedFill : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isNarrow
                            ? Center(
                                child: Icon(
                                  config.icon,
                                  size: 20,
                                  color: hasAccess ? onCard : onMuted,
                                ),
                              )
                            : Row(
                                children: [
                                  Icon(
                                    config.icon,
                                    size: 20,
                                    color: hasAccess ? onCard : onMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      config.label,
                                      style: TextStyle(
                                        color: hasAccess ? onCard : onMuted,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );

                    return isNarrow
                        ? Tooltip(
                            message: config.label,
                            child: Center(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: tile,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: tile,
                          );
                  },
                ),
              ),

              // Logout em vermelho
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 0 : 12,
                  8,
                  isNarrow ? 0 : 12,
                  16,
                ),
                child: isNarrow
                    ? IconOnlyButton(
                        onPressed: widget.onLogout,
                        icon: Icons.logout,
                        iconColor: errorRed,
                        tooltip: 'Sair',
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: widget.onLogout,
                          style: TextButton.styleFrom(
                            foregroundColor: errorRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sair'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }
}

