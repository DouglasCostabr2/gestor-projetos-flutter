import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../modules/modules.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function() onLoggedIn;
  const LoginPage({super.key, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Usando o módulo de autenticação ao invés de chamada direta
      await authModule.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro inesperado');
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
                  Text('Entrar', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
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

