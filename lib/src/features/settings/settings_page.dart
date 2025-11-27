import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../state/app_state_scope.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import '../../../modules/modules.dart';

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
  bool _linkingGoogle = false;
  bool _unlinkingGoogle = false;
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

      final newFullName = _fullNameController.text.trim();

      // Verificar se o nome já existe (exceto para o próprio usuário)
      final existingUsers = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('full_name', newFullName)
          .neq('id', user.id);

      if (existingUsers.isNotEmpty) {
        throw Exception(
            'Este nome já está em uso por outro usuário. Por favor, escolha um nome diferente.');
      }

      // Atualizar perfil
      await Supabase.instance.client.from('profiles').update({
        'full_name': newFullName,
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      }).eq('id', user.id);

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

      // Forçar atualização do usuário
      await Supabase.instance.client.auth.refreshSession();

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

  Future<void> _linkGoogleAccount() async {
    setState(() {
      _linkingGoogle = true;
      _error = null;
      _success = null;
    });

    try {
      final success = await authModule.linkGoogleAccount();

      if (mounted) {
        if (success) {
          // Aguardar um pouco para o Supabase atualizar o usuário
          await Future.delayed(const Duration(milliseconds: 500));

          // Forçar rebuild para atualizar o status da conta Google
          setState(() {
            _success = 'Conta Google vinculada com sucesso!';
          });
        } else {
          setState(() => _error = 'Erro ao vincular conta Google');
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');

        // Mostrar dialog com instruções se for erro de manual linking
        if (errorMessage.contains('Vinculação manual está desabilitada')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Vinculação Manual Desabilitada'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Para vincular sua conta Google, você precisa habilitar a vinculação manual no Supabase Dashboard.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Passos para habilitar:'),
                    const SizedBox(height: 8),
                    const Text('1. Acesse o Supabase Dashboard'),
                    const Text('2. Vá em Auth → Providers'),
                    const Text('3. Role até "Security Settings"'),
                    const Text('4. Habilite "Enable Manual Linking"'),
                    const Text('5. Salve as configurações'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        } else {
          setState(() => _error = errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _linkingGoogle = false);
      }
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    // Confirmar antes de desvincular
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular Conta Google'),
        content: const Text(
          'Tem certeza que deseja desvincular sua conta Google?\n\n'
          'Você ainda poderá fazer login com email e senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _unlinkingGoogle = true;
      _error = null;
      _success = null;
    });

    try {
      final success = await authModule.unlinkGoogleAccount();

      if (mounted) {
        if (success) {
          // Aguardar um pouco para o Supabase atualizar o usuário
          await Future.delayed(const Duration(milliseconds: 500));

          // Forçar rebuild para atualizar o status da conta Google
          setState(() {
            _success = 'Conta Google desvinculada com sucesso!';
          });
        } else {
          setState(() => _error = 'Erro ao desvincular conta Google');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is AuthException) {
          errorMessage = e.message;
        } else {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }

        // Mostrar dialog se for erro de senha não definida (precisa criar senha)
        if (errorMessage.contains('NEEDS_PASSWORD_CREATION')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Defina uma Senha Primeiro'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Para desvincular sua conta Google, você precisa primeiro definir uma senha.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Como fazer:'),
                    const SizedBox(height: 8),
                    const Text('1. Role para cima até a seção "Alterar Senha"'),
                    const Text('2. Digite uma nova senha'),
                    const Text('3. Confirme a senha'),
                    const Text('4. Clique em "Alterar Senha"'),
                    const SizedBox(height: 16),
                    const Text(
                      'Depois disso, você poderá desvincular sua conta Google com segurança.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        } else if (errorMessage.contains('NEEDS_PASSWORD_CONFIRMATION')) {
          // Solicitar senha para confirmação com diálogo stateful
          await _showPasswordConfirmationDialog();
          // Don't execute finally block's setState - we handled it in the dialog
          return;
        } else {
          setState(() => _error = errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _unlinkingGoogle = false);
      }
    }
  }

  Future<void> _showPasswordConfirmationDialog() async {
    final passwordController = TextEditingController();
    String? dialogError;
    bool isLoading = false;
    bool hasText = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Adicionar listener para atualizar o estado quando o texto mudar
          passwordController.removeListener(() {});
          passwordController.addListener(() {
            setDialogState(() {
              hasText = passwordController.text.isNotEmpty;
            });
          });

          return AlertDialog(
            title: const Text('Confirmação Necessária'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para sua segurança, por favor confirme sua senha atual para desvincular a conta Google.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Sua Senha Atual',
                    border: const OutlineInputBorder(),
                    errorText: dialogError,
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                  onSubmitted: (_) async {
                    if (passwordController.text.isNotEmpty && !isLoading) {
                      await _confirmPasswordAndUnlink(
                        passwordController.text,
                        setDialogState,
                        (error) => dialogError = error,
                        (loading) => isLoading = loading,
                      );
                    }
                  },
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() => _unlinkingGoogle = false);
                        }
                      },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isLoading || !hasText
                    ? null
                    : () async {
                        await _confirmPasswordAndUnlink(
                          passwordController.text,
                          setDialogState,
                          (error) => dialogError = error,
                          (loading) => isLoading = loading,
                        );
                      },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmPasswordAndUnlink(
    String password,
    StateSetter setDialogState,
    Function(String?) setError,
    Function(bool) setLoading,
  ) async {
    setDialogState(() {
      setError(null);
      setLoading(true);
    });

    try {
      final success = await authModule.confirmPasswordAndUnlink(password);

      if (mounted) {
        if (success) {
          // Fechar o diálogo
          Navigator.pop(context);

          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            _success = 'Conta Google desvinculada com sucesso!';
            _error = null;
            _unlinkingGoogle = false;
          });
        } else {
          setDialogState(() {
            setError('Erro ao desvincular conta Google');
            setLoading(false);
          });
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (e is AuthException) {
        errorMsg = e.message;
      } else {
        errorMsg = errorMsg.replaceFirst('Exception: ', '');
      }

      // Se o erro for NEEDS_PASSWORD_CREATION, fechar o modal e mostrar o diálogo de criar senha
      if (errorMsg.contains('NEEDS_PASSWORD_CREATION')) {
        if (mounted) {
          Navigator.pop(context); // Fechar modal de confirmação
          setState(() => _unlinkingGoogle = false);

          // Mostrar diálogo explicativo
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Defina uma Senha Primeiro'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Para desvincular sua conta Google, você precisa primeiro definir uma senha.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Como fazer:'),
                    const SizedBox(height: 8),
                    const Text('1. Role para cima até a seção "Alterar Senha"'),
                    const Text('2. Digite uma nova senha'),
                    const Text('3. Confirme a senha'),
                    const Text('4. Clique em "Alterar Senha"'),
                    const SizedBox(height: 16),
                    const Text(
                      'Depois disso, você poderá desvincular sua conta Google com segurança.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        }
      } else {
        // Outros erros: mostrar no modal
        setDialogState(() {
          setError(errorMsg);
          setLoading(false);
        });
      }
    }
  }

  Future<void> _uploadAvatar() async {
    // Obter organization_id ANTES de qualquer operação async
    final appState = AppStateScope.of(context);
    final organizationId = appState.currentOrganizationId;
    if (organizationId == null) {
      setState(() => _error = 'Nenhuma organização ativa');
      return;
    }

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
          : _fullNameController.text
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = 'avatar-$userName.jpg';
      final path = '$organizationId/$fileName';

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
          // URL format: https://.../storage/v1/object/public/avatars/{org_id}/avatar_xxx.jpg
          final uri = Uri.parse(oldUrl);
          final pathSegments = uri.pathSegments;
          // Verificar se é formato novo (com org_id) ou legado (sem org_id)
          if (pathSegments.length >= 5 &&
              pathSegments[pathSegments.length - 3] == 'avatars') {
            // Formato novo: avatars/{org_id}/avatar_xxx.jpg
            final oldPath =
                '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
            try {
              await Supabase.instance.client.storage
                  .from('avatars')
                  .remove([oldPath]);
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
          } else if (pathSegments.length >= 4 &&
              pathSegments[pathSegments.length - 2] == 'avatars') {
            // Formato legado: avatars/avatar_xxx.jpg
            final oldPath = pathSegments.last;
            try {
              await Supabase.instance.client.storage
                  .from('avatars')
                  .remove([oldPath]);
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
          }
        }
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }

      // Fazer upload do novo avatar
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Obter URL pública
      final publicUrl =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(path);

      // Atualizar perfil com nova URL
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', user.id);

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
                                  backgroundImage: _avatarUrl != null &&
                                          _avatarUrl!.isNotEmpty
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child:
                                      _avatarUrl == null || _avatarUrl!.isEmpty
                                          ? const Icon(Icons.person, size: 50)
                                          : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          width: 2),
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
                                _fullNameController.text.isEmpty
                                    ? 'Usuário'
                                    : _fullNameController.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _emailController.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildInfoChip(
                                    icon: Icons.badge,
                                    label: _getRoleLabel(_role ?? 'convidado'),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  if (_createdAt != null)
                                    _buildInfoChip(
                                      icon: Icons.calendar_today,
                                      label:
                                          'Desde ${_formatDate(_createdAt!)}',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red))),
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
                        border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(_success!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer))),
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
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira seu nome';
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira seu email';
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
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Salvar Alterações',
                              onPressed: _savingProfile ? null : _saveProfile,
                              isLoading: _savingProfile,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

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
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            label: 'Alterar Senha',
                            onPressed:
                                _changingPassword ? null : _changePassword,
                            isLoading: _changingPassword,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Google Account Section
                  _buildSection(
                    title: 'Conta Google',
                    icon: Icons.link,
                    child: Column(
                      children: [
                        if (authModule.hasGoogleAccount)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Sua conta está vinculada ao Google',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _unlinkingGoogle
                                      ? null
                                      : _unlinkGoogleAccount,
                                  child: _unlinkingGoogle
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Desvincular',
                                          style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151515),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Row(
                              children: [
                                Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                  height: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Vincular conta Google',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _linkingGoogle
                                      ? null
                                      : _linkGoogleAccount,
                                  child: _linkingGoogle
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Vincular'),
                                ),
                              ],
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
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'manager':
        return 'Gerente';
      case 'designer':
        return 'Designer';
      case 'client':
        return 'Cliente';
      default:
        return 'Convidado';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM yyyy', 'pt_BR').format(date);
    } catch (e) {
      return '';
    }
  }
}
