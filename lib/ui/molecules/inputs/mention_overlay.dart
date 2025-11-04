import 'package:flutter/material.dart';
import 'dart:async';
import '../../../services/users_cache_service.dart';

/// Overlay de autocomplete para menções
///
/// Este widget é usado internamente pelo MentionTextField e outros
/// componentes que precisam de suporte a menções.
///
/// Características:
/// - Cache de usuários (5 minutos)
/// - Debounce na busca (300ms)
/// - Paginação (20 usuários por vez)
class MentionOverlay {
  final BuildContext context;
  final LayerLink layerLink;
  final ValueChanged<Map<String, dynamic>> onUserSelected;

  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoadingUsers = false;

  // Debounce
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  // Paginação
  static const _pageSize = 20;

  final UsersCacheService _cacheService = UsersCacheService();

  MentionOverlay({
    required this.context,
    required this.layerLink,
    required this.onUserSelected,
  });

  Future<void> loadUsers() async {
    if (_isLoadingUsers) return;

    _isLoadingUsers = true;

    try {
      _users = await _cacheService.getUsers();
      _isLoadingUsers = false;
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
      _isLoadingUsers = false;
    }
  }

  void show(String query) {
    // Cancelar timer anterior
    _debounceTimer?.cancel();

    // Criar novo timer com debounce
    _debounceTimer = Timer(_debounceDuration, () {
      _filterUsers(query);

      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
        return;
      }

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: 300,
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 40),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF1A1A1A),
              child: _buildUsersList(),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  void hide() {
    _debounceTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      _filteredUsers = _users.take(_pageSize).toList();
      return;
    }

    // Usar o cache service para filtrar
    final filtered = _cacheService.filterUsers(query);
    _filteredUsers = filtered.take(_pageSize).toList();
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Nenhum usuário encontrado',
          style: TextStyle(
            color: Color(0xFF9AA0A6),
            fontSize: 14,
          ),
        ),
      );
    }
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _buildUserItem(user);
        },
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'Sem nome';
    final email = user['email'] ?? '';
    final avatarUrl = user['avatar_url'];
    
    return InkWell(
      onTap: () {
        onUserSelected(user);
        hide();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Nome e email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFEAEAEA),
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _debounceTimer?.cancel();
    hide();
  }
}

/// Helper para detectar e gerenciar menções em um TextField
class MentionTextFieldHelper {
  final TextEditingController controller;
  final MentionOverlay overlay;

  int _mentionStartPosition = -1;

  // Mapa para armazenar o relacionamento entre nomes e IDs
  final Map<String, String> _mentionMap = {};

  MentionTextFieldHelper({
    required this.controller,
    required this.overlay,
  }) {
    controller.addListener(_onTextChanged);
  }

  /// Retorna o mapa de menções (nome -> userId)
  Map<String, String> get mentions => Map.unmodifiable(_mentionMap);

  void _onTextChanged() {
    final text = controller.text;
    final selection = controller.selection;
    
    if (!selection.isValid || selection.baseOffset < 0) {
      overlay.hide();
      return;
    }
    
    final cursorPosition = selection.baseOffset;
    
    // Procurar por @ antes do cursor
    int atPosition = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // Verificar se há espaço ou início da string antes do @
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atPosition = i;
          break;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }
    
    if (atPosition >= 0) {
      // Extrair query após o @
      final query = text.substring(atPosition + 1, cursorPosition);

      // Verificar se não há espaços na query
      if (!query.contains(' ') && !query.contains('\n')) {
        _mentionStartPosition = atPosition;
        overlay.show(query);
        return;
      }
    }

    overlay.hide();
  }

  void insertMention(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'Sem nome';
    final userId = user['id'] as String;

    final text = controller.text;
    final beforeMention = text.substring(0, _mentionStartPosition);

    // IMPORTANTE: Pegar o texto APÓS o cursor atual, não após a posição inicial do @
    // Isso garante que se o usuário digitou algo após o @, será removido
    final afterMention = text.substring(controller.selection.baseOffset);

    // Formato: @[Nome](userId) - será exibido como @Nome pelo MentionText
    final mention = '@[$name]($userId)';

    // Adicionar um espaço após a menção para separar do próximo texto
    final newText = '$beforeMention$mention $afterMention';

    // Armazenar o mapeamento nome -> userId
    _mentionMap[name] = userId;

    // Posicionar o cursor APÓS o espaço que vem depois da menção
    final cursorPosition = beforeMention.length + mention.length + 1;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

    overlay.hide();
  }

  /// Extrai os IDs dos usuários mencionados no texto
  List<String> extractMentionedUserIds(String text) {
    final regex = RegExp(r'@([A-Za-zÀ-ÿ\s]+)');
    final matches = regex.allMatches(text);
    final userIds = <String>[];

    for (final match in matches) {
      final name = match.group(1)?.trim();
      if (name != null && _mentionMap.containsKey(name)) {
        userIds.add(_mentionMap[name]!);
      }
    }

    return userIds;
  }

  void dispose() {
    controller.removeListener(_onTextChanged);
  }
}

