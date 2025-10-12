import 'package:flutter/material.dart';
import '../../src/navigation/app_page.dart';
import '../../src/navigation/user_role.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

/// Diálogo para selecionar qual página abrir em uma nova aba
class NewTabDialog extends StatelessWidget {
  final UserRole userRole;

  const NewTabDialog({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final options = _getAvailablePages();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tab, color: Color(0xFFEAEAEA)),
                const SizedBox(width: 12),
                Text(
                  'Nova Aba',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFEAEAEA),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconOnlyButton(
                  icon: Icons.close,
                  iconColor: const Color(0xFF9AA0A6),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione qual página deseja abrir',
              style: TextStyle(color: Color(0xFF9AA0A6)),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _PageOption(
                    icon: option.icon,
                    label: option.label,
                    onTap: () => Navigator.pop(context, option.page),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_PageOptionData> _getAvailablePages() {
    final pages = <_PageOptionData>[];

    // Home - todos
    pages.add(_PageOptionData(
      page: AppPage.home,
      icon: Icons.home,
      label: 'Home',
    ));

    // Clientes - apenas não-clientes
    if (userRole != UserRole.cliente) {
      pages.add(_PageOptionData(
        page: AppPage.clients,
        icon: Icons.people,
        label: 'Clientes',
      ));
    }

    // Projetos - todos
    pages.add(_PageOptionData(
      page: AppPage.projects,
      icon: Icons.work,
      label: 'Projetos',
    ));

    // Catálogo - apenas não-clientes
    if (userRole != UserRole.cliente) {
      pages.add(_PageOptionData(
        page: AppPage.catalog,
        icon: Icons.storefront,
        label: 'Catálogo',
      ));
    }

    // Tarefas - todos
    pages.add(_PageOptionData(
      page: AppPage.tasks,
      icon: Icons.checklist,
      label: 'Tarefas',
    ));

    // Financeiro - apenas admin, gestor, financeiro
    if (userRole.hasFinanceAccess) {
      pages.add(_PageOptionData(
        page: AppPage.finance,
        icon: Icons.account_balance_wallet,
        label: 'Financeiro',
      ));
    }

    // Admin - apenas admin
    if (userRole == UserRole.admin) {
      pages.add(_PageOptionData(
        page: AppPage.admin,
        icon: Icons.admin_panel_settings,
        label: 'Admin',
      ));
    }

    // Monitoramento - apenas admin e gestor
    if (userRole == UserRole.admin || userRole == UserRole.gestor) {
      pages.add(_PageOptionData(
        page: AppPage.monitoring,
        icon: Icons.monitor_heart,
        label: 'Monitoramento',
      ));
    }

    return pages;
  }
}

class _PageOptionData {
  final AppPage page;
  final IconData icon;
  final String label;

  _PageOptionData({
    required this.page,
    required this.icon,
    required this.label,
  });
}

class _PageOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PageOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PageOption> createState() => _PageOptionState();
}

class _PageOptionState extends State<_PageOption> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF2A2A2A)
                : const Color(0xFF252525),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF0078D4)
                  : const Color(0xFF2A2A2A),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 24,
                color: const Color(0xFFEAEAEA),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFFEAEAEA),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

