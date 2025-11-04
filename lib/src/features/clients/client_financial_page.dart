import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_shell.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/user_role.dart';
import '../../../ui/organisms/navigation/side_menu.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import '../../../core/di/service_locator.dart';
import '../../navigation/interfaces/tab_manager_interface.dart';

import 'widgets/client_financial_section.dart';

class ClientFinancialPage extends StatelessWidget {
  final String clientId;
  const ClientFinancialPage({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    // Verificar permissão: apenas Admin, Gestor e Financeiro
    if (!appState.isAdmin && !appState.isGestor && !appState.isFinanceiro) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas Administradores, Gestores e Financeiros podem acessar as informações financeiras do cliente.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SideMenu(
            collapsed: appState.sideMenuCollapsed,
            selectedIndex: 0,
            onSelect: (i) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AppShell(appState: appState, initialIndex: i)),
              );
            },
            onToggle: () => appState.toggleSideMenu(),
            onLogout: () async {
              final navigator = Navigator.of(context);
              // Limpar todas as abas antes do logout
              final tabManager = serviceLocator.get<ITabManager>();
              tabManager.clearAllTabs();
              await Supabase.instance.client.auth.signOut();
              if (!navigator.mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AppShell(appState: appState)),
                (route) => false,
              );
            },
            userRole: UserRoleExtension.fromString(appState.role),
            profile: appState.profile,
            appState: appState,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconOnlyButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Voltar',
                      ),
                      Text('Financeiro do Cliente', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: ClientFinancialSection(clientId: clientId)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

