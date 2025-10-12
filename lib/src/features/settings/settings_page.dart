import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../state/app_state_scope.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  String? _error;
  String? _success;
  String? _avatarUrl;
  String? _role;
  String? _createdAt;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email, phone, avatar_url, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        _fullNameController.text = profile['full_name'] ?? '';
        _emailController.text = profile['email'] ?? user.email ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _avatarUrl = profile['avatar_url'];
        _role = profile['role'];
        _createdAt = profile['created_at'];
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao carregar perfil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _savingProfile = true;
      _error = null;
      _success = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Atualizar perfil
      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          })
          .eq('id', user.id);

      // Atualizar email se mudou
      if (_emailController.text.trim() != user.email) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: _emailController.text.trim()),
        );
      }

      if (mounted) {
        // Atualizar AppState
        final appState = AppStateScope.of(context);
        await appState.refreshProfile();

        setState(() => _success = 'Perfil atualizado com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao salvar perfil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'As senhas não coincidem');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres');
      return;
    }

    setState(() {
      _changingPassword = true;
      _error = null;
      _success = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        setState(() {
          _success = 'Senha alterada com sucesso!';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao alterar senha: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      // Selecionar arquivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      setState(() {
        _loading = true;
        _error = null;
        _success = null;
      });

      // Ler bytes do arquivo
      Uint8List imageBytes;
      if (file.bytes != null) {
        imageBytes = file.bytes!;
      } else if (file.path != null) {
        // No desktop, usar o caminho do arquivo
        final imageFile = File(file.path!);
        imageBytes = await imageFile.readAsBytes();
      } else {
        if (mounted) {
          setState(() {
            _error = 'Erro ao ler arquivo';
            _loading = false;
          });
        }
        return;
      }

      // Decodificar imagem
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        if (mounted) {
          setState(() {
            _error = 'Formato de imagem inválido';
            _loading = false;
          });
        }
        return;
      }

      // Redimensionar para 400x400 (mantendo proporção)
      final resized = img.copyResize(
        originalImage,
        width: 400,
        height: 400,
        interpolation: img.Interpolation.linear,
      );

      // Comprimir como JPEG com qualidade 85
      final compressed = img.encodeJpg(resized, quality: 85);

      // Upload para Supabase Storage
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Sanitizar nome do usuário para usar no nome do arquivo
      final userName = _fullNameController.text.trim().isEmpty
          ? 'usuario'
          : _fullNameController.text.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = 'avatar-$userName.jpg';
      final path = 'avatars/$fileName';

      // Deletar avatar antigo se existir (para liberar espaço)
      try {
        // Buscar avatar_url atual do perfil
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && profile['avatar_url'] != null) {
          final oldUrl = profile['avatar_url'] as String;
          // Extrair o caminho do arquivo da URL
          // URL format: https://.../storage/v1/object/public/avatars/avatar_xxx.jpg
          final uri = Uri.parse(oldUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 4 && pathSegments[pathSegments.length - 2] == 'avatars') {
            final oldPath = 'avatars/${pathSegments.last}';
            try {
              await Supabase.instance.client.storage
                  .from('avatars')
                  .remove([oldPath]);
              debugPrint('✅ Avatar antigo deletado: $oldPath');
            } catch (e) {
              debugPrint('⚠️ Erro ao deletar avatar antigo (pode não existir): $e');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao verificar avatar antigo: $e');
      }

      // Fazer upload do novo avatar
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Obter URL pública
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      // Atualizar perfil com nova URL
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      if (mounted) {
        // Atualizar AppState
        final appState = AppStateScope.of(context);
        await appState.refreshProfile();

        setState(() {
          _avatarUrl = publicUrl;
          _success = 'Foto de perfil atualizada com sucesso!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao fazer upload da foto: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: const Color(0xFF151515),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Configurações',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gerencie suas informações pessoais e preferências',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

          // Account Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                // Avatar com botões de ação
                Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null || _avatarUrl!.isEmpty
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                            ),
                            child: IconOnlyButton(
                              icon: Icons.camera_alt,
                              iconSize: 18,
                              iconColor: Colors.white,
                              padding: const EdgeInsets.all(8),
                              tooltip: 'Alterar foto',
                              onPressed: _uploadAvatar,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullNameController.text.isEmpty ? 'Usuário' : _fullNameController.text,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.badge,
                            label: _getRoleLabel(_role ?? 'convidado'),
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          if (_createdAt != null)
                            _buildInfoChip(
                              icon: Icons.calendar_today,
                              label: 'Desde ${_formatDate(_createdAt!)}',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Messages
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),

          if (_success != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_success!, style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer))),
                ],
              ),
            ),

          // Profile Section
          _buildSection(
            title: 'Informações do Perfil',
            icon: Icons.person,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe seu nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, informe seu email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '(00) 00000-0000',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _savingProfile ? null : _saveProfile,
                        icon: _savingProfile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_savingProfile ? 'Salvando...' : 'Salvar Perfil'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Password Section
          _buildSection(
            title: 'Alterar Senha',
            icon: Icons.lock,
            child: Column(
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Nova Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Nova Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _changingPassword ? null : _changePassword,
                      icon: _changingPassword
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.vpn_key),
                      label: Text(_changingPassword ? 'Alterando...' : 'Alterar Senha'),
                    ),
                  ],
                ),
              ],
            ),
          ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'designer':
        return 'Designer';
      case 'financeiro':
        return 'Financeiro';
      case 'cliente':
        return 'Cliente';
      default:
        return 'Convidado';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

