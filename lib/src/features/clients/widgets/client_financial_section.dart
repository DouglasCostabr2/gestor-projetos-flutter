import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/src/utils/money.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../../../services/google_drive_oauth_service.dart';
import '../../../../ui/organisms/dialogs/drive_connect_dialog.dart';
import '../../../../ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

import '../../../state/app_state_scope.dart';

class ClientFinancialSection extends StatefulWidget {
  final String clientId;
  const ClientFinancialSection({super.key, required this.clientId});

  @override
  State<ClientFinancialSection> createState() => _ClientFinancialSectionState();
}

class _ClientFinancialSectionState extends State<ClientFinancialSection> {
  bool _loading = true;
  String? _error;

  // Summary per currency
  int brlTotal = 0, brlReceived = 0;
  int usdTotal = 0, usdReceived = 0;
  int eurTotal = 0, eurReceived = 0;

  List<_ProjectFinance> _projects = [];
  String _clientName = 'Cliente';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final supa = Supabase.instance.client;
      final projects = List<Map<String, dynamic>>.from(await supa
          .from('projects')
          .select('id, name, currency_code, value_cents, company_id, organization_id, clients(name), companies(name)')
          .eq('client_id', widget.clientId)
          .order('created_at', ascending: false));
      // tenta obter o nome do cliente (qualquer projeto serve, pois todos têm o mesmo client_id)
      if (projects.isNotEmpty) {
        final c = projects.first['clients']?['name'] as String?;
        if (c != null && c.trim().isNotEmpty) {
          _clientName = c.trim();
        }
      }
      final ids = projects.map((e) => e['id'] as String).toList();

      Map<String, int> addCosts = {};
      Map<String, int> received = {};
      if (ids.isNotEmpty) {
        final costsRows = await supa
            .from('project_additional_costs')
            .select('project_id, amount_cents')
            .inFilter('project_id', ids);
        for (final r in costsRows) {
          final pid = r['project_id'] as String;
          addCosts[pid] = (addCosts[pid] ?? 0) + (r['amount_cents'] as int? ?? 0);
        }
        final paymentsRows = await supa
            .from('payments')
            .select('project_id, amount_cents')
            .inFilter('project_id', ids);
        for (final r in paymentsRows) {
          final pid = r['project_id'] as String;
          received[pid] = (received[pid] ?? 0) + (r['amount_cents'] as int? ?? 0);
        }
      }

      // Buscar organizações únicas
      final orgIds = projects
          .map((p) => p['organization_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> orgNames = {};
      if (orgIds.isNotEmpty) {
        final orgs = await supa
            .from('organizations')
            .select('id, name')
            .inFilter('id', orgIds);
        for (final org in orgs) {
          orgNames[org['id'] as String] = org['name'] as String;
        }
      }

      int tBRL = 0, rBRL = 0, tUSD = 0, rUSD = 0, tEUR = 0, rEUR = 0;
      final list = <_ProjectFinance>[];
      for (final p in projects) {
        final pid = p['id'] as String;
        final cur = (p['currency_code'] as String?) ?? 'BRL';
        final base = (p['value_cents'] as int?) ?? 0;
        final add = addCosts[pid] ?? 0;
        final tot = base + add;
        final rec = received[pid] ?? 0;
        final companyName = p['companies']?['name'] as String?;
        final organizationId = p['organization_id'] as String?;
        final organizationName = organizationId != null ? orgNames[organizationId] : null;

        list.add(_ProjectFinance(
          id: pid,
          name: (p['name'] as String?) ?? '-',
          currency: cur,
          totalCents: tot,
          receivedCents: rec,
          companyName: companyName,
          organizationName: organizationName,
        ));
        switch (cur) {
          case 'USD':
            tUSD += tot; rUSD += rec; break;
          case 'EUR':
            tEUR += tot; rEUR += rec; break;
          default:
            tBRL += tot; rBRL += rec; break;
        }
      }

      if (!mounted) return;
      setState(() {
        _projects = list;
        brlTotal = tBRL; brlReceived = rBRL;
        usdTotal = tUSD; usdReceived = rUSD;
        eurTotal = tEUR; eurReceived = rEUR;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _format(int cents) {
    return Money.formatCents(cents);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final canAccessFinance = app.isAdmin || app.isFinanceiro || app.isGestor;
    if (!canAccessFinance) return const SizedBox.shrink();
    if (_loading) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: Text('Erro: $_error'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Financeiro', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconOnlyButton(onPressed: _reload, icon: Icons.refresh, tooltip: 'Atualizar'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _SummaryCard(title: 'Total Projetos (BRL)', value: 'R\$ ${_format(brlTotal)}', secondary: 'Recebido: R\$ ${_format(brlReceived)}  |  Pendente: R\$ ${_format(brlTotal - brlReceived)}'),
          _SummaryCard(title: 'Total Projetos (USD)', value: '\$ ${_format(usdTotal)}', secondary: 'Recebido: \$ ${_format(usdReceived)}  |  Pendente: \$ ${_format(usdTotal - usdReceived)}'),
          _SummaryCard(title: 'Total Projetos (EUR)', value: '€ ${_format(eurTotal)}', secondary: 'Recebido: € ${_format(eurReceived)}  |  Pendente: € ${_format(eurTotal - eurReceived)}'),
        ]),
        const SizedBox(height: 16),
        Text('Projetos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(children: _projects.map((p) {
          final pending = (p.totalCents - p.receivedCents).clamp(0, 1<<31);
          final progress = p.totalCents <= 0 ? 0.0 : (p.receivedCents / p.totalCents).clamp(0.0, 1.0);
          final sym = Money.symbol(p.currency);
          final canPay = app.isAdmin || app.isFinanceiro;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleMedium)),
                  if (canPay) FilledButton.tonal(
                    onPressed: () async {
                      final added = await showDialog<bool>(
                        context: context,
                        builder: (_) => _PaymentDialog(
                          projectId: p.id,
                          currency: p.currency,
                          clientName: _clientName,
                          projectName: p.name,
                          companyName: p.companyName,
                          organizationName: p.organizationName,
                        ),
                      );
                      if (added == true) _reload();
                    },
                    child: const Text('Registrar pagamento'),
                  ),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('Total: $sym ${_format(p.totalCents)}')),
                  Expanded(child: Text('Recebido: $sym ${_format(p.receivedCents)}')),
                  Expanded(child: Text('Pendente: $sym ${_format(pending)}')),
                ]),
                const SizedBox(height: 8),
                _PaymentsList(projectId: p.id, currencySymbol: sym),
              ]),
            ),
          );
        }).toList()),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? secondary;
  const _SummaryCard({required this.title, required this.value, this.secondary});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (secondary != null) ...[
              const SizedBox(height: 4),
              Text(secondary!, style: Theme.of(context).textTheme.bodySmall),
            ]
          ]),
        ),
      ),
    );
  }
}

class _PaymentsList extends StatefulWidget {
  final String projectId;
  final String currencySymbol;
  const _PaymentsList({required this.projectId, required this.currencySymbol});

  @override
  State<_PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends State<_PaymentsList> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final res = await Supabase.instance.client
          .from('payments')
          .select('id, amount_cents, created_at, method, note, receipt_url')
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { _rows = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _rows = []; _loading = false; });
    }
  }

  String _fmt(int cents) => Money.formatWithSymbol(cents, widget.currencySymbol == 'R\$' ? 'BRL' : (widget.currencySymbol == '\$' ? 'USD' : 'EUR'));
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
    if (_loading) return const LinearProgressIndicator();
    if (_rows.isEmpty) return const Text('Nenhum pagamento registrado');
    String fmtDateShort(dynamic v) {
      DateTime? dt; if (v is DateTime) { dt = v; } else if (v is String) { try { dt = DateTime.parse(v); } catch (_) {} }
      if (dt == null) return '-';
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$d/$m/$y';
    }
    return Column(children: _rows.map((r) {
      final note = (r['note'] as String?) ?? '';
      final method = (r['method'] as String?) ?? '';
      final cleanedNote = _cleanNote(note) ?? '';
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.payments_outlined),
        title: Builder(builder: (ctx) {
          final urlStr = _paymentReceiptUrl(r);
          final canManagePayments = AppStateScope.of(context).isAdmin || AppStateScope.of(context).isFinanceiro || AppStateScope.of(context).isGestor;
          return Row(children: [
            Text(_fmt((r['amount_cents'] as int?) ?? 0)),
            if (urlStr != null) const SizedBox(width: 8),
            if (urlStr != null)
              SizedBox(
                height: 22,
                child: TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), minimumSize: const Size(0, 22)),
                  onPressed: () async {
                    final url = Uri.tryParse(urlStr);
                    if (url != null) { await launchUrl(url, mode: LaunchMode.externalApplication); }
                  },
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
                        await Supabase.instance.client.from('payments').delete().eq('id', r['id']);
                        if (context.mounted) _load();
                      } catch (_) {}
                      // Ignorar erro (operação não crítica)
                    }
                  } else if (v == 'edit') {
                    final code = widget.currencySymbol == 'R\$' ? 'BRL' : (widget.currencySymbol == '\$' ? 'USD' : 'EUR');
                    final updated = await showDialog<bool>(context: context, builder: (_) => _EditPaymentDialog(payment: r, currencyCode: code));
                    if (updated == true) _load();
                  }
                },
              ),
          ]);
        }),
        subtitle: Text([fmtDateShort(r['created_at']), if (method.isNotEmpty) method, if (cleanedNote.isNotEmpty) cleanedNote].join('  ·  ')),
      );
    }).toList());
  }
}

class _PaymentDialog extends StatefulWidget {
  final String projectId;
  final String currency;
  final String? clientName;
  final String? projectName;
  final String? companyName;
  final String? organizationName;
  const _PaymentDialog({required this.projectId, required this.currency, this.clientName, this.projectName, this.companyName, this.organizationName});

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

  int _parseCents(String s) {
    final v = double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    return (v * 100).round();
  }

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
    return StandardDialog(
      title: 'Registrar pagamento',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : () async {
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
                      // Ignorar erro (operação não crítica)
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
                      companyName: widget.companyName,
                      organizationName: widget.organizationName,
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
                if (_receiptUrl != null) {
                  final prev = (payload2['note'] as String?) ?? '';
                  payload2['note'] = prev.isEmpty ? 'Comprovante: $_receiptUrl' : '$prev  ·  Comprovante: $_receiptUrl';
                }
                await Supabase.instance.client.from('payments').insert(payload2);
              }
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
              // Best-effort: tentar atualizar status financeiro se existir essa coluna
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
          },
          child: const Text('Salvar'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
    );
  }
}

class _ProjectFinance {
  final String id;
  final String name;
  final String currency;
  final int totalCents;
  final int receivedCents;
  final String? companyName;
  final String? organizationName;
  _ProjectFinance({required this.id, required this.name, required this.currency, required this.totalCents, required this.receivedCents, this.companyName, this.organizationName});
}



class _EditPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> payment;
  final String currencyCode;
  const _EditPaymentDialog({required this.payment, required this.currencyCode});
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
    final sym = Money.symbol(widget.currencyCode);
    return StandardDialog(
      title: 'Editar pagamento',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : () async {
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
          },
          child: const Text('Salvar'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
    );
  }
}
