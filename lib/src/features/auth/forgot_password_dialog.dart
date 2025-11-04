import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../modules/modules.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Por favor, insira seu email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await authModule.resetPasswordForEmail(
        email: _emailCtrl.text.trim(),
      );
      setState(() => _success = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao enviar email de recuperação');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar Senha'),
      content: _success
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Email enviado com sucesso!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifique seu email para instruções de recuperação de senha.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'seu.email@example.com',
                  ),
                  enabled: !_loading,
                  onSubmitted: (_) => _sendResetEmail(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviaremos um link de recuperação para seu email.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (!_success)
          FilledButton(
            onPressed: _loading ? null : _sendResetEmail,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar'),
          ),
        if (_success)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
      ],
    );
  }
}

