import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../modules/modules.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = 'Por favor, preencha todos os campos');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'As senhas não correspondem');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await authModule.updatePassword(newPassword: password);
      setState(() => _success = true);
      
      // Aguardar 2 segundos e voltar para login
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao atualizar senha');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_success)
                    Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Senha Atualizada!',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sua senha foi atualizada com sucesso. Você será redirecionado para o login.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Redefinir Senha',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        TextField(
                          controller: _passwordCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nova Senha',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                    () => _showPassword = !_showPassword);
                              },
                            ),
                          ),
                          obscureText: !_showPassword,
                          enabled: !_loading,
                          onSubmitted: (_) => _resetPassword(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordCtrl,
                          decoration: InputDecoration(
                            labelText: 'Confirmar Senha',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _showConfirmPassword =
                                        !_showConfirmPassword);
                              },
                            ),
                          ),
                          obscureText: !_showConfirmPassword,
                          enabled: !_loading,
                          onSubmitted: (_) => _resetPassword(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Atualizar Senha'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

