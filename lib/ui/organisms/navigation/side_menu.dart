import 'package:flutter/material.dart';
import '../../../src/navigation/user_role.dart';
import '../../../src/navigation/app_page.dart';
import '../../../src/state/app_state.dart';
import 'menu_item_config.dart';
import '../../atoms/avatars/cached_avatar.dart';
import '../../atoms/buttons/buttons.dart';
import '../../molecules/organization_switcher.dart';
import '../../../src/features/notifications/widgets/notification_badge.dart';
import '../../../modules/notifications/module.dart';

// OTIMIZAÇÃO: Constantes de design extraídas para evitar recriação
const _kCardColor = Color(0xFF151515);
const _kOnCard = Color(0xFFEAEAEA);
const _kOnMuted = Color(0xFF9AA0A6);
const _kBorderColor = Color(0xFF2A2A2A);
const _kDividerColor = Color(0xFF2A2A2A);
const _kSelectedFill = Color(0x1AFFFFFF); // 10% white overlay
const _kErrorRed = Color(0xFFFF4D4D);

// OTIMIZAÇÃO: Decoração const para evitar recriação
const _kMenuDecoration = BoxDecoration(
  color: _kCardColor,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  border: Border.fromBorderSide(BorderSide(color: _kBorderColor)),
  boxShadow: [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ],
);

/// Widget do menu lateral da aplicação
/// MUDADO PARA STATEFUL para escutar eventos de notificação
class SideMenu extends StatefulWidget {
  final bool collapsed;
  final int selectedIndex;
  final void Function(int) onSelect;
  final VoidCallback onToggle;
  final VoidCallback onLogout;
  final UserRole userRole;
  final Map<String, dynamic>? profile;
  final AppState appState;

  const SideMenu({
    super.key,
    required this.collapsed,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggle,
    required this.onLogout,
    required this.userRole,
    required this.appState,
    this.profile,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  @override
  void initState() {
    super.initState();
    notificationEventBus.events.addListener(_onNotificationEvent);
  }

  @override
  void dispose() {
    notificationEventBus.events.removeListener(_onNotificationEvent);
    super.dispose();
  }

  void _onNotificationEvent() {
    if (!mounted) return;
    final event = notificationEventBus.events.value;
    if (event == null) return;
    setState(() {}); // Force rebuild to update NotificationBadge
  }

  @override
  Widget build(BuildContext context) {
    // OTIMIZAÇÃO: AnimatedContainer anima apenas a largura
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: widget.collapsed ? 72 : 260,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: _kMenuDecoration,
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Header com toggle
              _MenuHeader(
                collapsed: widget.collapsed,
                onToggle: widget.onToggle,
              ),

              // Seletor de Organização
              OrganizationSwitcher(
                appState: widget.appState,
                collapsed: widget.collapsed,
              ),

              // Navegação
              Expanded(
                child: _MenuNavigation(
                  collapsed: widget.collapsed,
                  selectedIndex: widget.selectedIndex,
                  userRole: widget.userRole,
                  onSelect: widget.onSelect,
                ),
              ),

              // Perfil + Configurações + Logout (movido para baixo)
              _BottomSection(
                collapsed: widget.collapsed,
                profile: widget.profile,
                userRole: widget.userRole,
                onLogout: widget.onLogout,
                onSelect: widget.onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// OTIMIZAÇÃO: Widget separado para o header
/// Evita rebuilds desnecessários
class _MenuHeader extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const _MenuHeader({
    required this.collapsed,
    required this.onToggle,
  });

  @override
  State<_MenuHeader> createState() => _MenuHeaderState();
}

class _MenuHeaderState extends State<_MenuHeader> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: widget.collapsed
          ? Center(
              child: GestureDetector(
                onTap: widget.onToggle,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/app_logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Botão com seta que aparece no hover
                      AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Logo do app
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/app_logo.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Business',
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
    );
  }
}

/// OTIMIZAÇÃO: Widget separado para a seção inferior (Perfil com menu dropdown)
class _BottomSection extends StatefulWidget {
  final bool collapsed;
  final Map<String, dynamic>? profile;
  final UserRole userRole;
  final VoidCallback onLogout;
  final void Function(int) onSelect;

  const _BottomSection({
    required this.collapsed,
    required this.profile,
    required this.userRole,
    required this.onLogout,
    required this.onSelect,
  });

  @override
  State<_BottomSection> createState() => _BottomSectionState();
}

class _BottomSectionState extends State<_BottomSection> {
  bool _menuExpanded = false;

  void _toggleMenu() {
    setState(() => _menuExpanded = !_menuExpanded);
  }

  void _closeMenu() {
    if (mounted) {
      setState(() => _menuExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Menu expandido (aparece acima do divider com animação)
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              child: _menuExpanded && !widget.collapsed
                  ? Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1E1E),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Configurações
                          InkWell(
                            onTap: () {
                              _closeMenu();
                              Future.delayed(const Duration(milliseconds: 200), () {
                                widget.onSelect(9);
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: const [
                                  Icon(Icons.settings, size: 20, color: _kOnCard),
                                  SizedBox(width: 12),
                                  Text('Configurações', style: TextStyle(color: _kOnCard)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: _kBorderColor),
                          // Sair
                          InkWell(
                            onTap: () {
                              _closeMenu();
                              Future.delayed(const Duration(milliseconds: 200), () {
                                widget.onLogout();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: const [
                                  Icon(Icons.logout, size: 20, color: _kErrorRed),
                                  SizedBox(width: 12),
                                  Text('Sair', style: TextStyle(color: _kErrorRed)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        // Divider antes da seção
        if (!widget.collapsed) const Divider(height: 1, color: _kDividerColor),

        // Perfil com botão de menu
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.collapsed ? 0 : 16,
            16,
            widget.collapsed ? 0 : 16,
            16,
          ),
          child: Container(
            padding: EdgeInsets.all(widget.collapsed ? 0 : 8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              color: Colors.transparent,
            ),
            child: widget.collapsed
                ? GestureDetector(
                    onTap: _toggleMenu,
                    child: CachedAvatar(
                      avatarUrl: widget.profile?['avatar_url'] as String?,
                      radius: 20,
                      fallbackIcon: Icons.person,
                    ),
                  )
                : Row(
                    children: [
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
                                    color: _kOnCard,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.userRole.label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _kOnMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Botão de menu "..."
                      IconButton(
                        onPressed: _toggleMenu,
                        icon: Icon(
                          _menuExpanded ? Icons.expand_less : Icons.more_vert,
                          color: _kOnMuted,
                        ),
                        tooltip: 'Menu',
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Widget para a navegação (StatelessWidget simples)
class _MenuNavigation extends StatelessWidget {
  final bool collapsed;
  final int selectedIndex;
  final UserRole userRole;
  final void Function(int) onSelect;

  const _MenuNavigation({
    required this.collapsed,
    required this.selectedIndex,
    required this.userRole,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Filtrar itens que o usuário tem acesso
    final accessibleItems = MenuConfig.items
        .asMap()
        .entries
        .where((entry) => entry.value.isAccessibleBy(userRole))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: accessibleItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, listIndex) {
        final entry = accessibleItems[listIndex];
        final config = entry.value;
        final pageIndex = config.page.index;

        return _MenuItem(
          config: config,
          collapsed: collapsed,
          selected: pageIndex == selectedIndex,
          userRole: userRole,
          onTap: () => onSelect(pageIndex),
        );
      },
    );
  }
}

/// Widget para cada item do menu
/// IMPORTANTE: Mudado para StatefulWidget para permitir rebuild quando NotificationBadge atualizar
class _MenuItem extends StatefulWidget {
  final MenuItemConfig config;
  final bool collapsed;
  final bool selected;
  final UserRole userRole;
  final VoidCallback onTap;

  const _MenuItem({
    required this.config,
    required this.collapsed,
    required this.selected,
    required this.userRole,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  @override
  Widget build(BuildContext context) {
    final hasAccess = widget.config.isAccessibleBy(widget.userRole);
    final isNotificationsPage = widget.config.page == AppPage.notifications;

    Widget iconWidget = Icon(
      widget.config.icon,
      size: 20,
      color: hasAccess ? _kOnCard : _kOnMuted,
    );

    // Adicionar badge de notificações se for a página de notificações
    if (isNotificationsPage) {
      iconWidget = NotificationBadge(child: iconWidget);
    }

    final tile = InkWell(
      onTap: hasAccess ? widget.onTap : null,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? 0 : 12,
        ),
        decoration: BoxDecoration(
          color: widget.selected ? _kSelectedFill : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: widget.collapsed
            ? Center(child: iconWidget)
            : Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.config.label,
                      style: TextStyle(
                        color: hasAccess ? _kOnCard : _kOnMuted,
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    return widget.collapsed
        ? Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: tile,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: tile,
          );
  }
}

