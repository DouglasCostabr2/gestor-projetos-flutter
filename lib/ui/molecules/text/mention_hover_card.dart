import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Card de hover que exibe informações do usuário mencionado
///
/// Mostra:
/// - Avatar do usuário
/// - Nome completo
/// - Role (cargo)
class MentionHoverCard extends StatefulWidget {
  final String userId;
  final Offset position;
  final VoidCallback onClose;

  const MentionHoverCard({
    super.key,
    required this.userId,
    required this.position,
    required this.onClose,
  });

  @override
  State<MentionHoverCard> createState() => _MentionHoverCardState();
}

class _MentionHoverCardState extends State<MentionHoverCard> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, avatar_url, role')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _userData = response;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar usuário';
          _loading = false;
        });
      }
    }
  }

  String _getRoleLabel(String? role) {
    if (role == null) return 'Usuário';

    final roleMap = {
      'admin': 'Administrador',
      'gestor': 'Gestor',
      'designer': 'Designer',
      'financeiro': 'Financeiro',
      'cliente': 'Cliente',
      'usuario': 'Usuário',
      'convidado': 'Convidado',
    };

    return roleMap[role.toLowerCase()] ?? role;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E1E1E),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2A2A2A),
              width: 1,
            ),
          ),
          child: _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 80,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          _error!,
          style: const TextStyle(
            color: Color(0xFF9AA0A6),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final avatarUrl = _userData!['avatar_url'] as String?;
    final fullName = _userData!['full_name'] as String? ?? 'Sem nome';
    final role = _userData!['role'] as String?;

    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2A2A),
            image: avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // Nome e Role
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  color: Color(0xFFEAEAEA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _getRoleLabel(role),
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

