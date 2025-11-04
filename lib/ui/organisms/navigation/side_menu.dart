import 'package:flutter/material.dart';
import '../../../src/navigation/user_role.dart';
import '../../../src/navigation/app_page.dart';
import '../../../src/state/app_state.dart';
import 'menu_item_config.dart';
import '../../atoms/avatars/cached_avatar.dart';
import '../../atoms/buttons/buttons.dart';
import '../../molecules/organization_switcher.dart';
import '../../../src/features/notifications/widgets/notification_badge.dart';

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
///
/// OTIMIZAÇÃO: Usa AnimatedContainer ao invés de AnimatedBuilder
/// para melhor performance nas animações de abrir/fechar
class SideMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // OTIMIZAÇÃO: AnimatedContainer anima apenas a largura
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? 72 : 260,
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
                collapsed: collapsed,
                onToggle: onToggle,
              ),

              // Perfil
              _ProfileSection(
                collapsed: collapsed,
                profile: profile,
                userRole: userRole,
              ),

              // Seletor de Organização
              OrganizationSwitcher(
                appState: appState,
                collapsed: collapsed,
              ),

              // Navegação
              Expanded(
                child: RepaintBoundary(
                  child: _MenuNavigation(
                    collapsed: collapsed,
                    selectedIndex: selectedIndex,
                    userRole: userRole,
                    onSelect: onSelect,
                  ),
                ),
              ),

              // Logout
              _LogoutButton(
                collapsed: collapsed,
                onLogout: onLogout,
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
class _MenuHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const _MenuHeader({
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: collapsed
          ? Center(
              child: IconOnlyButton(
                icon: Icons.chevron_right,
                onPressed: onToggle,
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
                    onPressed: onToggle,
                    tooltip: 'Recolher',
                  ),
                ],
              ),
            ),
    );
  }
}

/// OTIMIZAÇÃO: Widget separado para a seção de perfil
class _ProfileSection extends StatelessWidget {
  final bool collapsed;
  final Map<String, dynamic>? profile;
  final UserRole userRole;

  const _ProfileSection({
    required this.collapsed,
    required this.profile,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsed) const Divider(height: 1, color: _kDividerColor),
        Padding(
          padding: EdgeInsets.fromLTRB(
            collapsed ? 0 : 16,
            16,
            collapsed ? 0 : 16,
            8,
          ),
          child: Container(
            padding: EdgeInsets.all(collapsed ? 0 : 8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              color: Colors.transparent,
            ),
            child: collapsed
                ? Center(
                    child: CachedAvatar(
                      avatarUrl: profile?['avatar_url'] as String?,
                      radius: 20,
                      fallbackIcon: Icons.person,
                    ),
                  )
                : Row(
                    children: [
                      CachedAvatar(
                        avatarUrl: profile?['avatar_url'] as String?,
                        radius: 20,
                        fallbackIcon: Icons.person,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (profile?['full_name'] ?? 'Usuário') as String,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _kOnCard,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userRole.label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _kOnMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (!collapsed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: _kDividerColor, height: 24),
          ),
      ],
    );
  }
}

/// OTIMIZAÇÃO: Widget separado para a navegação
/// Usa RepaintBoundary para isolar repaints
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

    debugPrint('📋 [SideMenu] UserRole: $userRole, Itens acessíveis: ${accessibleItems.length}');
    debugPrint('📋 [SideMenu] Itens: ${accessibleItems.map((e) => e.value.label).join(', ')}');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: accessibleItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      // OTIMIZAÇÃO: Desabilita keepAlives se não precisar manter estado
      addAutomaticKeepAlives: false,
      // OTIMIZAÇÃO: Isola repaint de cada item
      addRepaintBoundaries: true,
      itemBuilder: (context, listIndex) {
        final entry = accessibleItems[listIndex];
        final config = entry.value;
        final pageIndex = config.page.index; // Usar o índice do AppPage enum

        return _MenuItem(
          config: config,
          collapsed: collapsed,
          selected: pageIndex == selectedIndex,
          userRole: userRole,
          onTap: () {
            debugPrint('🖱️ [SideMenu] Clique no item: ${config.label} (index: $pageIndex)');
            onSelect(pageIndex);
          },
        );
      },
    );
  }
}

/// OTIMIZAÇÃO: Widget separado para cada item do menu
class _MenuItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasAccess = config.isAccessibleBy(userRole);
    final isNotificationsPage = config.page == AppPage.notifications;

    Widget iconWidget = Icon(
      config.icon,
      size: 20,
      color: hasAccess ? _kOnCard : _kOnMuted,
    );

    // Adicionar badge de notificações se for a página de notificações
    if (isNotificationsPage) {
      iconWidget = NotificationBadge(child: iconWidget);
    }

    final tile = InkWell(
      onTap: hasAccess ? onTap : null,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? _kSelectedFill : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: collapsed
            ? Center(child: iconWidget)
            : Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config.label,
                      style: TextStyle(
                        color: hasAccess ? _kOnCard : _kOnMuted,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    return collapsed
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

/// OTIMIZAÇÃO: Widget separado para o botão de logout
class _LogoutButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onLogout;

  const _LogoutButton({
    required this.collapsed,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        collapsed ? 0 : 12,
        8,
        collapsed ? 0 : 12,
        16,
      ),
      child: collapsed
          ? IconOnlyButton(
              onPressed: onLogout,
              icon: Icons.logout,
              iconColor: _kErrorRed,
              tooltip: 'Sair',
            )
          : SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onLogout,
                style: TextButton.styleFrom(
                  foregroundColor: _kErrorRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ),
    );
  }
}

