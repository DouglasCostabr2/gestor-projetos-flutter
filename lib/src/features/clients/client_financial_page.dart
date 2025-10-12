import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_shell.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/user_role.dart';
import '../../../widgets/side_menu.dart';
import '../settings/settings_page.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

import 'widgets/client_financial_section.dart';

class ClientFinancialPage extends StatelessWidget {
  final String clientId;
  const ClientFinancialPage({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
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
              await Supabase.instance.client.auth.signOut();
              if (!navigator.mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AppShell(appState: appState)),
                (route) => false,
              );
            },
            onProfileTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            userRole: UserRoleExtension.fromString(appState.role),
            profile: appState.profile,
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

