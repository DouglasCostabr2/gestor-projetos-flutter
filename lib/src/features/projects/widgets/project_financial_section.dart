import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestor_projetos_flutter/src/utils/money.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../../../services/google_drive_oauth_service.dart';
import '../../../../widgets/drive_connect_dialog.dart';
import '../../../state/app_state_scope.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

class ProjectFinancialSection extends StatefulWidget {
  final String projectId;
  final String currencyCode; // BRL | USD | EUR
  const ProjectFinancialSection({super.key, required this.projectId, required this.currencyCode});

  @override
  State<ProjectFinancialSection> createState() => _ProjectFinancialSectionState();
}

class _ProjectFinancialSectionState extends State<ProjectFinancialSection> {
  bool _loading = true;

  String? _error;
  int _baseCents = 0;
  int _receivedCents = 0;
  String _projectName = 'Projeto';
  String _clientName = 'Cliente';
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final proj = await client
          .from('projects')
          .select('value_cents, name, clients(name)')
          .eq('id', widget.projectId)
          .single();
      _baseCents = (proj['value_cents'] as int?) ?? 0;
      _projectName = (proj['name'] as String?) ?? 'Projeto';
      _clientName = (proj['clients']?['name'] as String?) ?? 'Cliente';


      final pays = await client
          .from('payments')
          .select('id, amount_cents, created_at, method, note, receipt_url')
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false);
      _payments = List<Map<String, dynamic>>.from(pays);
      _receivedCents = 0;
      for (final p in _payments) { _receivedCents += (p['amount_cents'] as int?) ?? 0; }

      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // Total considerado para cobrança = value_cents do projeto (não somamos custos adicionais novamente)
  int get _totalCents => _baseCents;

  String _fmtDateShort(dynamic v) {
    DateTime? dt;
    if (v is DateTime) {
      dt = v;
    } else if (v is String) {
      try { dt = DateTime.parse(v); } catch (_) {}
    }
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  String? _extractUrlFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final i = text.indexOf('http');
    if (i < 0) return null;
    var sub = text.substring(i).trim();
    final space = sub.indexOf(' ');
    if (space > 0) sub = sub.substring(0, space);
    return sub;
  }

  String? _paymentReceiptUrl(Map<String, dynamic> p) {
    final direct = (p['receipt_url'] as String?)?.trim();
    if (direct != null && direct.startsWith('http')) return direct;
    return _extractUrlFromText(p['note'] as String?);
  }

  String? _cleanNote(String? text) {
    if (text == null || text.isEmpty) return null;
    final re = RegExp(r'comprovante:\s*https?:\/\/\S+', caseSensitive: false);
    var cleaned = text.replaceAll(re, '');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final canAccessFinance = app.isAdmin || app.isFinanceiro || app.isGestor;
    final canManagePayments = canAccessFinance;
    if (!canAccessFinance) return const SizedBox.shrink();
    if (_loading) return const LinearProgressIndicator();
    if (_error != null) return Text('Erro: $_error');
    final pending = (_totalCents - _receivedCents).clamp(0, 1<<31);
    final progress = _totalCents <= 0 ? 0.0 : (_receivedCents / _totalCents).clamp(0.0, 1.0);

    return Card(
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(children: [
            Text('Financeiro', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (canManagePayments)
              FilledButton.tonal(onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => _PaymentDialog(
                    projectId: widget.projectId,
                    currency: widget.currencyCode,
                    clientName: _clientName,
                    projectName: _projectName,
                  ),
                );
                if (added == true) _reload();
              }, child: const Text('Registrar pagamento')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _Metric('Total', Money.formatWithSymbol(_totalCents, widget.currencyCode))),
            const SizedBox(width: 8),
            Expanded(child: _Metric('Recebido', Money.formatWithSymbol(_receivedCents, widget.currencyCode))),
            const SizedBox(width: 8),
            Expanded(child: _Metric('Pendente', Money.formatWithSymbol(pending, widget.currencyCode))),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            const Text('Nenhum pagamento registrado')
          else ...[
            Text('Pagamentos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Column(
                  children: _payments.map((p) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined),
              title: Builder(builder: (ctx) {
                final urlStr = _paymentReceiptUrl(p);
                return Row(children: [
                  Text(Money.formatWithSymbol((p['amount_cents'] as int?) ?? 0, widget.currencyCode)),
                  if (urlStr != null) const SizedBox(width: 8),
                  if (urlStr != null)
                    SizedBox(
                      height: 22,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), minimumSize: const Size(0, 22)),
                        onPressed: () async { final url = Uri.tryParse(urlStr); if (url != null) { await launchUrl(url, mode: LaunchMode.externalApplication); } },
                        child: const Text('Comprovante'),
                      ),
                    ),
                  if (canManagePayments) const SizedBox(width: 8),
                  if (canManagePayments)
                    PopupMenuButton<String>(
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                      onSelected: (v) async {
                        if (v == 'delete') {
                          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                            title: const Text('Excluir pagamento'),
                            content: const Text('Tem certeza que deseja excluir este pagamento?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                            ],
                          ));
                          if (ok == true) {
                            try {
                              await Supabase.instance.client.from('payments').delete().eq('id', p['id']);
                              if (context.mounted) _reload();
                            } catch (_) {}
                          }
                        } else if (v == 'edit') {
                          final updated = await showDialog<bool>(context: context, builder: (_) => _EditPaymentDialog(payment: p, currency: widget.currencyCode));
                          if (updated == true) _reload();
                        }
                      },
                    ),
                ]);
              }),
              subtitle: Text([
                _fmtDateShort(p['created_at']),
                if ((p['method'] as String?)?.isNotEmpty == true) (p['method'] as String),
                if (_cleanNote(p['note'] as String?) != null) _cleanNote(p['note'] as String)!,
              ].join('  ·  ')),
            )).toList(),
                  ),
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }
}


class _EditPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> payment;
  final String currency;
  const _EditPaymentDialog({required this.payment, required this.currency});
  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountText;
  late TextEditingController _method;
  late TextEditingController _note;
  String? _receiptUrl;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountText = TextEditingController(text: Money.formatCents((widget.payment['amount_cents'] as int?) ?? 0));
    _method = TextEditingController(text: (widget.payment['method'] as String?) ?? '');
    _note = TextEditingController(text: (widget.payment['note'] as String?) ?? '');
    final url = widget.payment['receipt_url'] as String?;
    _receiptUrl = (url != null && url.isNotEmpty) ? url : null;
    debugPrint('🧾 Carregando pagamento para edição:');
    debugPrint('   ID: ${widget.payment['id']}');
    debugPrint('   Receipt URL: $_receiptUrl');
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
      withData: true,
      allowMultiple: false,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      if (f.bytes != null) {
        setState(() {
          _pickedImageBytes = f.bytes!;
          _pickedImageName = f.name;
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageName = null;
      _receiptUrl = null;
    });
  }

  int _parseCents(String? t) {
    if (t == null) return 0;
    final s = t.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll('.', '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0.0;
    return (d * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final sym = Money.symbol(widget.currency);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 70),
          child: Stack(children: [
            Positioned.fill(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Editar pagamento', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountText,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Valor', prefixText: '$sym '),
                    validator: (v) => (v==null||v.trim().isEmpty) ? 'Informe o valor' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: _method, decoration: const InputDecoration(labelText: 'Forma de pagamento (opcional)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
                  const SizedBox(height: 12),
                  // Botão para anexar comprovante
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickImage,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Anexar comprovante'),
                      ),
                    ),
                    if (_pickedImageBytes != null || (_receiptUrl != null && _receiptUrl!.isNotEmpty))
                      IconOnlyButton(
                        icon: Icons.close,
                        tooltip: 'Remover comprovante',
                        onPressed: _saving ? null : _removeImage,
                      ),
                  ]),
                  // Preview do comprovante
                  if (_pickedImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _pickedImageName?.toLowerCase().endsWith('.pdf') == true
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_pickedImageName ?? 'PDF', overflow: TextOverflow.ellipsis)),
                                  ]),
                                )
                              : Image.memory(_pickedImageBytes!, fit: BoxFit.contain),
                        ),
                      ),
                    )
                  else if (_receiptUrl != null && _receiptUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _receiptUrl!.toLowerCase().endsWith('.pdf')
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Comprovante PDF', overflow: TextOverflow.ellipsis)),
                                  ]),
                                )
                              : Image.network(_receiptUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: ElevationOverlay.applySurfaceTint(
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceTint,
                    Theme.of(context).dialogTheme.elevation ?? 6.0,
                  ),
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _saving ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() { _saving = true; });
                    try {
                      String? uploadedUrl = _receiptUrl;

                      // Se há uma nova imagem selecionada, fazer upload
                      if (_pickedImageBytes != null && _pickedImageName != null) {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          final timestamp = DateTime.now().millisecondsSinceEpoch;
                          final fileName = 'receipt_${widget.payment['id']}_$timestamp${_pickedImageName!.substring(_pickedImageName!.lastIndexOf('.'))}';
                          final path = 'receipts/$fileName';

                          await Supabase.instance.client.storage
                              .from('receipts')
                              .uploadBinary(
                                path,
                                _pickedImageBytes!,
                                fileOptions: FileOptions(
                                  contentType: _pickedImageName!.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/${_pickedImageName!.split('.').last}',
                                  upsert: true,
                                ),
                              );

                          uploadedUrl = Supabase.instance.client.storage
                              .from('receipts')
                              .getPublicUrl(path);
                        }
                      }

                      await Supabase.instance.client
                        .from('payments')
                        .update({
                          'amount_cents': _parseCents(_amountText.text),
                          'method': _method.text.trim().isEmpty ? null : _method.text.trim(),
                          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
                          'receipt_url': uploadedUrl,
                        })
                        .eq('id', widget.payment['id']);
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                    } finally {
                      if (mounted) setState(() { _saving = false; });
                    }
                  }, child: Text(_saving ? 'Salvando...' : 'Salvar')),
                ]),
              ),
            )
          ]),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ]),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String projectId;
  final String currency;
  final String? clientName;
  final String? projectName;
  const _PaymentDialog({required this.projectId, required this.currency, this.clientName, this.projectName});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountText = TextEditingController();
  final _method = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  // Comprovante
  final _drive = GoogleDriveOAuthService();
  PlatformFile? _receiptFile;
  String? _receiptUrl;

  int _parseCents(String s) => Money.parseToCents(s);

  @override
  void dispose() {
    _amountText.dispose();
    _method.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sym = Money.symbol(widget.currency);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stack(children: [
            Positioned.fill(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Registrar pagamento', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountText,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Valor', prefixText: '$sym '),
                    validator: (v) => (v==null||v.trim().isEmpty) ? 'Informe o valor' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: _method, decoration: const InputDecoration(labelText: 'Forma de pagamento (opcional)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () async {
                          final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg','jpeg','png','webp','gif','pdf'], withData: true);
                          if (res != null && res.files.isNotEmpty) {
                            setState(() { _receiptFile = res.files.first; _receiptUrl = null; });
                          }
                        },
                        icon: const Icon(Icons.attachment_outlined),
                        label: Text(_receiptFile == null ? 'Anexar comprovante' : 'Comprovante: ${_receiptFile!.name}'),
                      ),
                    ),
                    if (_receiptUrl != null) ...[
                      const SizedBox(width: 8),
                      IconOnlyButton(
                        tooltip: 'Abrir comprovante',
                        onPressed: () async { final url = Uri.tryParse(_receiptUrl!); if (url != null) { await launchUrl(url, mode: LaunchMode.externalApplication); } },
                        icon: Icons.open_in_new_rounded,
                      ),
                    ]
                  ]),
                  const SizedBox(height: 56),
                ]),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: ElevationOverlay.applySurfaceTint(
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceTint,
                    Theme.of(context).dialogTheme.elevation ?? 6.0,
                  ),
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _saving ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() { _saving = true; });
                    try {
                      // Se houver comprovante selecionado, enviar ao Drive primeiro
                      String? url;
                      if (_receiptFile != null && _receiptFile!.bytes != null) {
                        try {
                          auth.AuthClient? client;
                          try {
                            client = await _drive.getAuthedClient();
                          } on ConsentRequired catch (_) {
                            if (!context.mounted) return;
                            final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
                            if (ok == true) {
                              try { client = await _drive.getAuthedClient(); } catch (_) {}
                            }
                          }
                          if (client != null) {
                            final original = _receiptFile!.name;
                            final bytes = _receiptFile!.bytes!;
                            final now = DateTime.now();
                            final d = now.day.toString().padLeft(2, '0');
                            final m = now.month.toString().padLeft(2, '0');
                            final yy = (now.year % 100).toString().padLeft(2, '0');
                            String safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
                            final clientName = widget.clientName ?? 'Cliente';
                            final projectName = widget.projectName ?? 'Projeto';
                            final dot = original.lastIndexOf('.');
                            final ext = dot >= 0 ? original.substring(dot) : '';
                            final newName = 'Comprovante-${safe(clientName)}-${safe(projectName)}-$d-$m-$yy$ext';
                            final up = await _drive.uploadToProjectSubfolder(
                              client: client,
                              clientName: clientName,
                              projectName: projectName,
                              subfolderName: 'Financeiro',
                              filename: newName,
                              bytes: bytes,
                            );
                            url = up.publicViewUrl;
                            setState(() { _receiptUrl = url; });
                          }
                        } catch (e) {
                          // segue sem comprovante
                        }
                      }

                      final payload = {
                        'project_id': widget.projectId,
                        'amount_cents': _parseCents(_amountText.text),
                        'method': _method.text.trim().isEmpty ? null : _method.text.trim(),
                        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
                        'created_by': Supabase.instance.client.auth.currentUser?.id,
                        if (url != null) 'receipt_url': url,
                      };
                      try {
                        await Supabase.instance.client.from('payments').insert(payload);
                      } catch (e) {
                        // Fallback: coluna receipt_url pode não existir -> concatena na nota
                        final payload2 = Map<String, dynamic>.from(payload);
                        payload2.remove('receipt_url');
                        if (url != null) {
                          final prev = (payload2['note'] as String?) ?? '';
                          payload2['note'] = prev.isEmpty ? 'Comprovante: $url' : '$prev  ·  Comprovante: $url';
                        }
                        await Supabase.instance.client.from('payments').insert(payload2);
                      }

                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                      // Best-effort: atualizar status financeiro
                      try {
                        final agg = await Supabase.instance.client
                            .from('payments')
                            .select('amount_cents')
                            .eq('project_id', widget.projectId);
                        int received = 0;
                        for (final r in agg) { received += (r['amount_cents'] as int? ?? 0); }
                        final proj = await Supabase.instance.client
                            .from('projects')
                            .select('value_cents')
                            .eq('id', widget.projectId)
                            .single();
                        final total = (proj['value_cents'] as int? ?? 0);
                        final status = received >= total ? 'paid' : (received > 0 ? 'partial' : 'pending');
                        await Supabase.instance.client
                            .from('projects')
                            .update({'financial_status': status})
                            .eq('id', widget.projectId);
                      } catch (_) {}
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao registrar pagamento')));
                    } finally {
                      if (mounted) setState(() { _saving = false; });
                    }
                  }, child: Text(_saving ? 'Salvando...' : 'Salvar')),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

