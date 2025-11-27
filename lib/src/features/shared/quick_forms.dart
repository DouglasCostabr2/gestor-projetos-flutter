import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/services/briefing_upload_helpers.dart';
import 'package:my_business/services/assets_upload_helpers.dart';

import 'package:my_business/services/google_drive_oauth_service.dart';
import 'package:my_business/modules/tasks/module.dart';
import 'package:my_business/modules/common/organization_context.dart';

import 'package:my_business/src/features/tasks/widgets/task_history_widget.dart';
import 'package:my_business/src/features/tasks/widgets/task_assets_section.dart';
import 'package:my_business/src/features/tasks/widgets/task_briefing_section.dart';
import 'package:my_business/src/features/tasks/widgets/task_product_link_selector.dart';
import 'package:my_business/src/features/tasks/widgets/task_date_field.dart';
import 'package:my_business/src/features/tasks/widgets/task_assignees_field.dart';
import 'package:my_business/src/features/tasks/widgets/task_priority_field.dart';
import 'package:my_business/src/features/tasks/widgets/task_status_field.dart';
import 'package:my_business/modules/modules.dart';
import 'package:my_business/src/services/task_products_service.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_field.dart';
import 'package:my_business/services/mentions_service.dart';

/* LEGACY REMOVED: QuickProjectForm and _SelectCatalogItemDialogQuick (now using ProjectFormDialog)

class QuickProjectForm extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? initial; // null = criar, != null = editar
  const QuickProjectForm({super.key, required this.clientId, this.initial});
  @override
  State<QuickProjectForm> createState() => _QuickProjectFormState();
}

class _QuickProjectFormState extends State<QuickProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  // Finance fields
  final TextEditingController _valueText = TextEditingController();
  String _currencyCode = 'BRL'; // BRL | USD | EUR
  final List<_CostItem> _costs = [];

  // Catalog linkage (snapshot items)
  final List<_CatalogItem> _catalogItems = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i['name'] ?? '';
      _desc.text = i['description'] ?? '';
      // Carregar dados financeiros completos para edição
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final id = (i['id'] ?? '').toString();
        if (id.isNotEmpty) _loadProjectFinancial(id);
      });
    }
  }

  // Utils de dinheiro
  int _parseMoneyToCents(String input) {
    return Money.parseToCents(input);
  }

  String _formatCents(int cents) {
    return Money.formatCents(cents).replaceAll('.', ',').replaceAll(',', ',');
  }

  String _currencySymbol(String code) {
    return Money.symbol(code);
  }

  int get _catalogSumCents => _catalogItems.where((it) => it.currency == _currencyCode).fold<int>(0, (sum, it) => sum + (it.priceCents * it.quantity));

  Future<void> _loadProjectFinancial(String projectId) async {
    try {
      final proj = await Supabase.instance.client
          .from('projects')
          .select('currency_code, value_cents')
          .eq('id', projectId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _currencyCode = (proj?['currency_code'] as String?) ?? 'BRL';
        final vc = (proj?['value_cents'] as int?) ?? 0;
        _valueText.text = _formatCents(vc).replaceAll('.', ',');
      });
      await _loadAdditionalCosts(projectId);
      await _loadCatalogItems(projectId);
      if (!mounted) return;
      setState(() {
        if (_catalogItems.isNotEmpty) {
          _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
        }
      });
    } catch (_) {}
    // Ignorar erro (operação não crítica)
  }

  Future<void> _loadAdditionalCosts(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_additional_costs')
          .select('description, amount_cents')
          .eq('project_id', projectId);
      setState(() {
        _costs.clear();
        for (final r in rows as List<dynamic>) {
          final m = r as Map<String, dynamic>;
          final item = _CostItem();
          item.descController.text = (m['description'] as String?) ?? '';
          final cents = (m['amount_cents'] as int?) ?? 0;
          item.valueController.text = _formatCents(cents).replaceAll('.', ',');
          _costs.add(item);
        }
      });
    } catch (_) {}
    // Ignorar erro (operação não crítica)
  }

  Future<void> _loadCatalogItems(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_catalog_items')
          .select('kind, item_id, name, currency_code, price_cents, quantity, position')
          .eq('project_id', projectId)
          .order('position', ascending: true, nullsFirst: true);
      setState(() {
        _catalogItems.clear();
        for (final r in rows as List<dynamic>) {
          final m = r as Map<String, dynamic>;
          _catalogItems.add(_CatalogItem(
            itemType: (m['kind'] as String?) ?? 'product',
            itemId: (m['item_id'] as String?) ?? '',
            name: (m['name'] as String?) ?? '-',
            currency: (m['currency_code'] as String?) ?? _currencyCode,
            priceCents: (m['unit_price_cents'] as int?) ?? 0,
            quantity: (m['quantity'] as int?) ?? 1,
          ));
        }
      });
    } catch (_) {}
    // Ignorar erro (operação não crítica)
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _valueText.dispose();
    for (final item in _catalogItems) { item.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (widget.initial == null) {
        // Criar
        final payload = {
          'name': _name.text.trim(),
          'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          'client_id': widget.clientId,
          'owner_id': userId,
          'status': 'active',
          'currency_code': _currencyCode,
          'value_cents': _parseMoneyToCents(_valueText.text),
          if (userId != null) 'created_by': userId,
        };
        final inserted = await client.from('projects').insert(payload).select('id').maybeSingle();
        final projectId = (inserted?['id'] ?? '').toString();
        if (projectId.isNotEmpty && _catalogItems.isNotEmpty) {
          final rows = _catalogItems.asMap().entries.map((e) { final idx = e.key; final it = e.value; return {
                'project_id': projectId,
                'kind': it.itemType,
                'item_id': it.itemId,
                'name': it.name,
                'currency_code': it.currency,
                'unit_price_cents': it.priceCents,
                'quantity': it.quantity,
                'position': idx,
                if (userId != null) 'created_by': userId,
              }).toList();
          if (rows.isNotEmpty) {
            await client.from('project_catalog_items').insert(rows);
          }
        }
      } else {
        // Editar (não alterar owner_id/client_id aqui)
        final projectId = (widget.initial!['id'] ?? '').toString();
        final payload = {
          'name': _name.text.trim(),
          'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          'currency_code': _currencyCode,
          'value_cents': _parseMoneyToCents(_valueText.text),
          if (userId != null) 'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('projects').update(payload).eq('id', projectId);
        // Substituir itens do catálogo
        await client.from('project_catalog_items').delete().eq('project_id', projectId);
        if (_catalogItems.isNotEmpty) {
          final rows = _catalogItems.map((it) => {
                'project_id': projectId,
                'kind': it.itemType,
                'item_id': it.itemId,
                'name': it.name,
                'currency_code': it.currency,
                'unit_price_cents': it.priceCents,
                'quantity': it.quantity,
                if (userId != null) 'created_by': userId,
              }).toList();
          await client.from('project_catalog_items').insert(rows);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Erro ao salvar projeto')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final appState = AppStateScope.of(context);
    final canEditFinancial = appState.isAdminOrGestor || appState.isFinanceiro;
    return StandardDialog(
      title: isEdit ? 'Editar Projeto' : 'Novo Projeto',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextOnlyButton(onPressed: _saving ? null : () => Navigator.pop(context), label: 'Cancelar'),
        PrimaryButton(onPressed: _saving ? null : _save, label: 'Salvar', isLoading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                      GenericTextField(
                        controller: _name,
                        labelText: 'Nome *',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 12),
                      GenericTextField(controller: _desc, labelText: 'Descrição'),
                      const SizedBox(height: 12),
                      // Moeda + Valor
                      Row(children: [
                        Expanded(
                          child: GenericDropdownField<String>(
                            value: _currencyCode,
                            items: const [
                              DropdownItem(value: 'BRL', label: 'Real (BRL)'),
                              DropdownItem(value: 'USD', label: 'Dólar (USD)'),
                              DropdownItem(value: 'EUR', label: 'Euro (EUR)'),
                            ],
                            onChanged: canEditFinancial ? (v) {
                              if (v == null || v == _currencyCode) return;
                              setState(() {
                                _currencyCode = v;
                                if (_catalogItems.isNotEmpty) {
                                  _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                }
                              });
                            } : null,
                            labelText: 'Moeda',
                            enabled: canEditFinancial,
                            openUpwards: true, // Abre para cima pois está no footer
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GenericNumberField(
                            controller: _valueText,
                            enabled: canEditFinancial,
                            allowDecimals: true,
                            labelText: 'Valor do projeto',
                            prefixText: '${_currencySymbol(_currencyCode)} ',
                            helperText: 'Use vírgula ou ponto',
                          ),
                        ),
                      ]),
                      if (_catalogItems.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Soma itens do catálogo: ${_currencySymbol(_currencyCode)} ${_formatCents(_catalogSumCents).replaceAll('.', ',')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Itens do Catálogo
                      Row(children: [
                        Text('Itens do Catálogo', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await showDialog<_CatalogItem>(
                              context: context,
                              builder: (_) => _SelectCatalogItemDialogQuick(currency: _currencyCode),

class _SelectCatalogItemDialogQuickState extends State<_SelectCatalogItemDialogQuick> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;

      // Obter organization_id
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        throw Exception('Nenhuma organização ativa');
      }

      final prods = await client
          .from('products')
          .select('id, name, currency_code, price_cents')
          .eq('organization_id', orgId)
          .eq('currency_code', widget.currency);
      final packs = await client
          .from('packages')
          .select('id, name, currency_code, price_cents')
          .eq('organization_id', orgId)
          .eq('currency_code', widget.currency);
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(prods);
        _packages = List<Map<String, dynamic>>.from(packs);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Falha ao carregar cat\u00e1logo'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _fmt(int cents) => (cents / 100.0).toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: 'Selecionar do Catálogo',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      isLoading: _loading,
      actions: [
        TextOnlyButton(onPressed: () => Navigator.pop(context), label: 'Fechar'),
      ],
      child: _loading
          ? const SizedBox.shrink()
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    const TabBar(tabs: [Tab(text: 'Produtos'), Tab(text: 'Pacotes')]),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(children: [
                          // Produtos
                          ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _products.length,
                            itemBuilder: (ctx, i) {
                              final p = _products[i];
                              final cents = (p['price_cents'] as int?) ?? 0;
                              return ListTile(
                                title: Text((p['name'] ?? '-') as String),
                                subtitle: Text('${widget.currency} ${_fmt(cents)}'),
                                onTap: () {
                                  Navigator.pop(context, _CatalogItem(
                                    itemType: 'product',
                                    itemId: (p['id'] ?? '').toString(),
                                    name: (p['name'] ?? '-') as String,
                                    currency: widget.currency,
                                    priceCents: cents,
                                    quantity: 1,
                                  ));
                                },
                              );
                            },
                          ),
                          // Pacotes
                          ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _packages.length,
                            itemBuilder: (ctx, i) {
                              final pk = _packages[i];
                              final cents = (pk['price_cents'] as int?) ?? 0;
                              return ListTile(
                                title: Text((pk['name'] ?? '-') as String),
                                subtitle: Text('${widget.currency} ${_fmt(cents)}'),
                                onTap: () {
                                  Navigator.pop(context, _CatalogItem(
                                    itemType: 'package',
                                    itemId: (pk['id'] ?? '').toString(),
                                    name: (pk['name'] ?? '-') as String,
                                    currency: widget.currency,
                                    priceCents: cents,
                                    quantity: 1,
                                  ));
                                },
                              );
                            },
                          ),
                        ]),
                    ),
                  ],
                ),
    );
  }
}

                            );
                            if (selected != null) {
                              setState(() {
                                final idx = _catalogItems.indexWhere((e) => e.itemType == selected.itemType && e.itemId == selected.itemId);
                                if (idx >= 0) {
                                  _catalogItems[idx] = _catalogItems[idx].copyWith(quantity: _catalogItems[idx].quantity + 1);
                                } else {
                                  _catalogItems.add(selected);
                                }
                                if (canEditFinancial && _catalogItems.isNotEmpty) {
                                  _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar do Catálogo'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ReorderableDragList<CatalogItemSelection>(
                        items: _catalogItems,
                        enabled: true,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _catalogItems.removeAt(oldIndex);
                            _catalogItems.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, it, i) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.name, style: Theme.of(context).textTheme.bodyLarge),
                                    const SizedBox(height: 4),
                                    Text(it.itemType == 'product' ? 'Produto' : 'Pacote', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 140,
                                child: GenericNumberField(
                                  controller: it.priceController,
                                  enabled: canEditFinancial,
                                  allowDecimals: true,
                                  labelText: 'Preço',
                                  prefixText: '${_currencySymbol(_currencyCode)} ',
                                  onChanged: (v) {
                                    final cents = _parseMoneyToCents(v);
                                    it.updatePriceCents(cents);
                                    setState(() {
                                      if (canEditFinancial && _catalogItems.isNotEmpty) {
                                        _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: GenericNumberField(
                                  controller: it.quantityController,
                                  enabled: canEditFinancial,
                                  allowDecimals: false,
                                  labelText: 'Qtd',
                                  onChanged: (v) {
                                    final q = int.tryParse(v) ?? 1;
                                    it.updateQuantity(q.clamp(1, 999));
                                    setState(() {
                                      if (canEditFinancial && _catalogItems.isNotEmpty) {
                                        _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconOnlyButton(
                                icon: Icons.delete_outline,
                                tooltip: 'Remover',
                                onPressed: () {
                                  setState(() {
                                    _catalogItems.removeAt(i);
                                    if (canEditFinancial) {
                                      _valueText.text = _catalogItems.isEmpty ? _valueText.text : _formatCents(_catalogSumCents).replaceAll('.', ',');
                                    }
                                  });
                                },
                              ),
                            ]),
                          );
                        },
                        getKey: (it) => it.uniqueId,
                      ),
                    ],
                  ),
                ),
              ),
            );
  }
}
*/

class _CatalogItem {
  final String itemType; // 'product' | 'package'
  final String itemId;
  final String name;
  final String currency;
  int priceCents; // snapshot negociado (mutável)
  int quantity; // mutável
  final TextEditingController
      priceController; // Controller para o campo de preço
  final TextEditingController
      quantityController; // Controller para o campo de quantidade

  _CatalogItem({
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.currency,
    required this.priceCents,
    required this.quantity,
  })  : priceController = TextEditingController(
          text: (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ','),
        ),
        quantityController = TextEditingController(
          text: quantity.toString(),
        );

  // Métodos para atualizar valores sem recriar o objeto
  void updatePriceCents(int cents) {
    priceCents = cents;
  }

  void updateQuantity(int qty) {
    quantity = qty;
  }

  _CatalogItem copyWith({
    String? itemType,
    String? itemId,
    String? name,
    String? currency,
    int? priceCents,
    int? quantity,
  }) {
    final newItem = _CatalogItem(
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      priceCents: priceCents ?? this.priceCents,
      quantity: quantity ?? this.quantity,
    );
    // Se o preço mudou, atualiza o controller
    if (priceCents != null && priceCents != this.priceCents) {
      newItem.priceController.text =
          (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    } else {
      // Mantém o texto atual do controller (preserva o que o usuário está digitando)
      newItem.priceController.text = priceController.text;
    }
    // Se a quantidade mudou, atualiza o controller
    if (quantity != null && quantity != this.quantity) {
      newItem.quantityController.text = quantity.toString();
    } else {
      // Mantém o texto atual do controller (preserva o que o usuário está digitando)
      newItem.quantityController.text = quantityController.text;
    }
    return newItem;
  }

  void dispose() {
    priceController.dispose();
    quantityController.dispose();
  }
}

class _SelectCatalogItemDialogQuick extends StatefulWidget {
  final String currency;
  const _SelectCatalogItemDialogQuick({required this.currency});
  @override
  State<_SelectCatalogItemDialogQuick> createState() =>
      _SelectCatalogItemDialogQuickState();
}

class _SelectCatalogItemDialogQuickState
    extends State<_SelectCatalogItemDialogQuick> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supa = Supabase.instance.client;

      // Obter organization_id
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        throw Exception('Nenhuma organização ativa');
      }

      final prods = await supa
          .from('products')
          .select('id, name, price_cents, currency_code')
          .eq('organization_id', orgId)
          .eq('currency_code', widget.currency)
          .order('name');
      final packs = await supa
          .from('packages')
          .select('id, name, price_cents, currency_code')
          .eq('organization_id', orgId)
          .eq('currency_code', widget.currency)
          .order('name');
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(prods);
        _packages = List<Map<String, dynamic>>.from(packs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmt(int cents) =>
      (cents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
  String _sym(String? code) {
    if (code == 'USD') return '\$';
    if (code == 'EUR') return '€';
    return 'R\$';
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: 'Selecionar Item do Catálogo',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Erro: $_error',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const TabBar(
                      tabs: [Tab(text: 'Produtos'), Tab(text: 'Pacotes')]),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(children: [
                      ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _products[i];
                          return ListTile(
                            title: Text(p['name'] ?? ''),
                            subtitle: Text(
                                '${_sym(p['currency_code'] as String?)} ${_fmt((p['price_cents'] ?? 0) as int)}'),
                            onTap: () => Navigator.pop(
                                context,
                                _CatalogItem(
                                  itemType: 'product',
                                  itemId: p['id'] as String,
                                  name: p['name'] as String? ?? '-',
                                  currency:
                                      p['currency_code'] as String? ?? 'BRL',
                                  priceCents: p['price_cents'] as int? ?? 0,
                                  quantity: 1,
                                )),
                          );
                        },
                      ),
                      ListView.separated(
                        itemCount: _packages.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _packages[i];
                          return ListTile(
                            title: Text(p['name'] ?? ''),
                            subtitle: Text(
                                '${_sym(p['currency_code'] as String?)} ${_fmt((p['price_cents'] ?? 0) as int)}'),
                            onTap: () => Navigator.pop(
                                context,
                                _CatalogItem(
                                  itemType: 'package',
                                  itemId: p['id'] as String,
                                  name: p['name'] as String? ?? '-',
                                  currency:
                                      p['currency_code'] as String? ?? 'BRL',
                                  priceCents: p['price_cents'] as int? ?? 0,
                                  quantity: 1,
                                )),
                          );
                        },
                      ),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}

class QuickTaskForm extends StatefulWidget {
  final String? projectId; // usado no create
  final Map<String, dynamic>? initial; // null = criar, != null = editar
  const QuickTaskForm({super.key, required this.projectId, this.initial});
  @override
  State<QuickTaskForm> createState() => _QuickTaskFormState();
}

class _QuickTaskFormState extends State<QuickTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _briefingText = '';
  String _briefingJson = '';
  bool _saving = false;
  // Project & Members/Assignee
  String? _projectId;
  List<String> _assigneeUserIds = []; // múltiplos responsáveis
  List<Map<String, dynamic>> _members = [];
  // Priority & Due date
  String _priority = 'medium';
  DateTime? _dueDate;

  // Catálogo do Projeto → vínculo de produtos (múltiplos)
  List<Map<String, dynamic>> _linkedProducts = [];

  // Attachments
  List<PlatformFile> _assetsImages = [];
  List<PlatformFile> _assetsFiles = [];
  List<PlatformFile> _assetsVideos = [];

  // Existing attachments (assets) for edit mode - removed (not used in QuickTaskForm)

  // Informações para Google Drive (briefing images)
  String? _projectName;
  String? _clientName;
  String? _companyName;
  String? _companyId; // Para Design Materials

  // UUID provisório para tasks novas (permite adicionar Design Materials antes de salvar)
  late final String _provisionalTaskId;

  // Referências de Design Materials (armazenadas em memória até salvar)
  List<Map<String, dynamic>> _designMaterialsRefs = [];

  // Drive service
  final _drive = GoogleDriveOAuthService();

  // Métodos removidos: _loadExistingAssets, _openDownloadFromAsset, _buildExistingAssetThumb, _deleteExistingAsset
  // QuickTaskForm não gerencia assets existentes - apenas novos uploads

  @override
  void initState() {
    super.initState();

    // Gerar UUID provisório para tasks novas
    _provisionalTaskId = const Uuid().v4();

    final i = widget.initial;
    if (i != null) {
      _title.text = i['title'] ?? '';
      _priority = (i['priority'] as String?) ?? 'medium';
      _projectId = i['project_id'] as String? ?? widget.projectId;

      // Carregar responsáveis (suporta assigned_to antigo e assignee_user_ids novo)
      final assigneeUserIds = i['assignee_user_ids'] as List?;
      if (assigneeUserIds != null && assigneeUserIds.isNotEmpty) {
        _assigneeUserIds = assigneeUserIds.cast<String>();
      } else {
        final assignedTo = i['assigned_to'] as String?;
        _assigneeUserIds = assignedTo != null ? [assignedTo] : [];
      }

      final due = i['due_date'] as String?;
      if (due != null && due.isNotEmpty) {
        try {
          _dueDate = DateTime.parse(due);
        } catch (_) {}
        // Ignorar erro (operação não crítica)
      }
      final d = (i['description'] as String?) ?? '';
      // Try to parse as JSON first (AppFlowy format)
      try {
        final parsed = jsonDecode(d);
        if (parsed is Map) {
          _briefingJson = d;
        } else {
          _briefingText = d;
        }
      } catch (_) {
        // If not JSON, treat as plain text
        _briefingText = d;
      }
    } else {
      _projectId = widget.projectId;
    }

    if (_projectId != null) {
      _loadMembers(_projectId!);
      _loadProjectAndClientInfo(_projectId!);
    } else {}

    // Load linked products if editing existing task
    if (i != null && i['id'] != null) {
      _loadLinkedProducts(i['id'] as String);
    }
    // Removed: _loadExistingAssets - QuickTaskForm doesn't manage existing assets
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadMembers(String projectId) async {
    try {
      // Buscar membros do projeto
      final res = await Supabase.instance.client
          .from('project_members')
          .select(
              'user_id, profiles:user_id(full_name, email, role, avatar_url)')
          .eq('project_id', projectId);
      final all = List<Map<String, dynamic>>.from(res);

      // Não filtrar por roles - mostrar todos os membros do projeto
      var filtered = all;

      // Fallback: buscar membros da organização se o projeto não tem membros
      if (filtered.isEmpty) {
        final orgId = OrganizationContext.currentOrganizationId;
        if (orgId != null) {
          try {
            final orgMembers = await Supabase.instance.client.rpc(
              'get_organization_members_with_profiles',
              params: {'org_id': orgId},
            );

            filtered = (orgMembers as List).map((m) {
              final member = m as Map<String, dynamic>;
              return {
                'user_id': member['user_id'],
                'profiles': {
                  'id': member['user_id'],
                  'full_name': member['full_name'],
                  'email': member['email'],
                  'avatar_url': member['avatar_url'],
                  'role': member['role'],
                },
              };
            }).toList();
          } catch (e) {
            // Silently fail - filtered will remain empty
          }
        }
      }

      if (mounted) setState(() => _members = filtered);
    } catch (e) {
      if (mounted) setState(() => _members = []);
    }
  }

  Future<void> _loadProjectAndClientInfo(String projectId) async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select(
              'name, client_id, company_id, clients:client_id(name), companies:company_id(name)')
          .eq('id', projectId)
          .maybeSingle();

      if (project != null && mounted) {
        setState(() {
          _projectName = project['name'] as String?;
          _clientName = (project['clients'] as Map?)?['name'] as String?;
          _companyName = (project['companies'] as Map?)?['name'] as String?;
          _companyId =
              project['company_id'] as String?; // Para Design Materials
        });
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _loadLinkedProducts(String taskId) async {
    try {
      if (_projectId == null || _projectId!.isEmpty) return;
      final list = await TaskProductsService.loadLinkedProducts(taskId,
          projectId: _projectId!);
      if (mounted) setState(() => _linkedProducts = list);
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return; // reentrancy guard
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    // use local context directly with mounted checks; avoid caching across async gaps
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (widget.initial == null) {
        // Criar
        // Validar prioridade
        final validPriorities = ['low', 'medium', 'high', 'urgent'];
        final safePriority =
            validPriorities.contains(_priority) ? _priority : 'medium';

        // Criar tarefa IMEDIATAMENTE com JSON local (URLs file://)
        // Upload de imagens será feito em background depois
        // Usar UUID provisório para permitir referências de Design Materials
        final taskRow = await tasksModule.createTask(
          id: _provisionalTaskId, // UUID provisório gerado no initState
          title: _title.text.trim(),
          description: _briefingJson.isNotEmpty
              ? _briefingJson
              : (_briefingText.isNotEmpty ? _briefingText : null),
          projectId: _projectId ?? widget.projectId!,
          assignedTo:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds.first : null,
          assigneeUserIds:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds : null,
          status: 'todo',
          priority: safePriority,
          dueDate: _dueDate,
        );

        // Atualizar prioridade baseada no prazo
        final taskId = taskRow['id'] as String;
        await tasksModule.updateSingleTaskPriority(taskId);

        // Salvar referências de Design Materials (se houver)
        if (_designMaterialsRefs.isNotEmpty) {
          for (final ref in _designMaterialsRefs) {
            try {
              await client.from('task_files').insert({
                'task_id': taskId,
                'filename': ref['filename'],
                'drive_file_id': ref['drive_file_id'],
                'drive_file_url': ref['drive_file_url'],
                'mime_type': ref['mime_type'],
                'size_bytes': ref[
                    'file_size_bytes'], // Coluna é 'size_bytes', não 'file_size_bytes'
                'category': 'assets',
                'created_by': userId,
              });
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
          }
        }

        // Salvar menções do título
        final mentionsService = MentionsService();
        try {
          await mentionsService.saveTaskMentions(
            taskId: taskId,
            fieldName: 'title',
            content: _title.text,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // Upload de imagens do briefing em BACKGROUND (não bloqueia o salvamento)
        if (_clientName != null && _projectName != null) {
          startBriefingImagesBackgroundUpload(
            taskId: taskId,
            briefingJson: _briefingJson,
            clientName: _clientName!,
            projectName: _projectName!,
            taskTitle: _title.text.trim().isNotEmpty
                ? _title.text.trim()
                : 'Nova Tarefa',
            companyName: _companyName,
          );
        }

        // Atualizar o projeto também (updated_by e updated_at)
        if (widget.projectId != null && userId != null) {
          try {
            await client.from('projects').update({
              'updated_by': userId,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', widget.projectId!);
          } catch (e) {
            // Ignorar erro (operação não crítica)
          }
        }

        // Upload Assets em segundo plano (se houver)
        await startAssetsBackgroundUpload(
          taskId: taskRow['id'] as String,
          clientName: _clientName ?? 'Cliente',
          projectName: _projectName ?? 'Projeto',
          taskTitle:
              _title.text.trim().isNotEmpty ? _title.text.trim() : 'Tarefa',
          assetsImages: _assetsImages,
          assetsFiles: _assetsFiles,
          assetsVideos: _assetsVideos,
          companyName: _companyName,
          context: mounted ? context : null,
          driveService: _drive,
        );

        // Save linked products to task_products table
        // Save linked products to task_products table
        try {
          final taskId = taskRow['id'] as String;
          await TaskProductsService.saveLinkedProducts(
            taskId: taskId,
            linkedProducts: _linkedProducts,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      } else {
        // Editar
        final beforeStatus =
            (widget.initial!['status'] as String?)?.toLowerCase();

        // Validar prioridade
        final validPriorities = ['low', 'medium', 'high', 'urgent'];
        final safePriority =
            validPriorities.contains(_priority) ? _priority : 'medium';

        try {
          // Atualizar tarefa IMEDIATAMENTE com JSON local (URLs file://)
          // Upload de imagens será feito em background depois
          await tasksModule.updateTask(
            taskId: widget.initial!['id'],
            title: _title.text.trim(),
            description: _briefingJson.isNotEmpty
                ? _briefingJson
                : (_briefingText.isNotEmpty ? _briefingText : null),
            assignedTo:
                _assigneeUserIds.isNotEmpty ? _assigneeUserIds.first : null,
            assigneeUserIds:
                _assigneeUserIds.isNotEmpty ? _assigneeUserIds : null,
            priority: safePriority,
            dueDate: _dueDate,
          );

          // Atualizar prioridade baseada no prazo
          await tasksModule.updateSingleTaskPriority(widget.initial!['id']);

          // Salvar referências de Design Materials (se houver)
          if (_designMaterialsRefs.isNotEmpty) {
            for (final ref in _designMaterialsRefs) {
              try {
                await client.from('task_files').insert({
                  'task_id': widget.initial!['id'],
                  'filename': ref['filename'],
                  'drive_file_id': ref['drive_file_id'],
                  'drive_file_url': ref['drive_file_url'],
                  'mime_type': ref['mime_type'],
                  'size_bytes': ref[
                      'file_size_bytes'], // Coluna é 'size_bytes', não 'file_size_bytes'
                  'category': 'assets',
                  'created_by': userId,
                });
              } catch (e) {
                // Ignorar erro (operação não crítica)
              }
            }
          }

          // Salvar menções do título
          final mentionsService = MentionsService();
          try {
            await mentionsService.saveTaskMentions(
              taskId: widget.initial!['id'],
              fieldName: 'title',
              content: _title.text,
            );
          } catch (e) {
            // Ignorar erro (operação não crítica)
          }

          // Upload de imagens do briefing em BACKGROUND (não bloqueia o salvamento)
          if (_clientName != null && _projectName != null) {
            startBriefingImagesBackgroundUpload(
              taskId: widget.initial!['id'],
              briefingJson: _briefingJson,
              clientName: _clientName!,
              projectName: _projectName!,
              taskTitle: _title.text.trim().isNotEmpty
                  ? _title.text.trim()
                  : widget.initial!['title'] ?? 'Tarefa',
              companyName: _companyName,
            );
          }

          // Atualizar o projeto também (updated_by e updated_at)
          if (widget.projectId != null && userId != null) {
            try {
              await client.from('projects').update({
                'updated_by': userId,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', widget.projectId!);
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
          }
        } catch (e) {
          rethrow;
        }

        final afterTask = await client
            .from('tasks')
            .select(
                'status, title, projects:project_id(name, clients:client_id(name))')
            .eq('id', widget.initial!['id'])
            .single();

        // Upload Assets em segundo plano (se houver)
        await startAssetsBackgroundUpload(
          taskId: widget.initial!['id'] as String,
          clientName: (afterTask['projects']?['clients']?['name'] ?? 'Cliente')
              .toString(),
          projectName: (afterTask['projects']?['name'] ?? 'Projeto').toString(),
          taskTitle: (afterTask['title'] ?? 'Tarefa').toString(),
          assetsImages: _assetsImages,
          assetsFiles: _assetsFiles,
          assetsVideos: _assetsVideos,
          companyName: _companyName,
          context: mounted ? context : null,
          driveService: _drive,
        );
        final afterStatus = (afterTask['status'] as String?)?.toLowerCase();
        final turnedCompleted =
            beforeStatus != 'completed' && afterStatus == 'completed';
        final leftCompleted =
            beforeStatus == 'completed' && afterStatus != 'completed';
        if (turnedCompleted || leftCompleted) {
          try {
            final clientName =
                (afterTask['projects']?['clients']?['name'] ?? 'Cliente')
                    .toString();
            final projectName =
                (afterTask['projects']?['name'] ?? 'Projeto').toString();
            final taskTitle = (afterTask['title'] ?? 'Tarefa').toString();
            final drive = GoogleDriveOAuthService();
            final authed = await drive.getAuthedClient();
            if (turnedCompleted) {
              await drive.addCompletedBadgeToTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
              );
            } else if (leftCompleted) {
              await drive.removeCompletedBadgeFromTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
              );
            }
          } catch (e) {
            // Ignorar erro (operação não crítica)
          }
        }

        // Processar Briefing (delta)  subir imagens embutidas e salvar JSON
        /* OLD QUILL CODE - DISABLED
        try {
          // final List<Map<String, dynamic>> ops = List<Map<String, dynamic>>.from(_briefingCtrl.document.toDelta().toJson());
          final List<Map<String, dynamic>> ops = [];
          final usedBriefingNames = <String>{};
          String uniqueBriefingName(String name) {
            var candidate = name; int i = 1;
            while (usedBriefingNames.contains(candidate)) {
              final dot = candidate.lastIndexOf('.');
              final base = dot >= 0 ? candidate.substring(0, dot) : candidate;
              final ext = dot >= 0 ? candidate.substring(dot) : '';
              candidate = "$base ($i)$ext"; i++;
            }
            usedBriefingNames.add(candidate); return candidate;
          }
          auth.AuthClient? authed;
          for (var i = 0; i < ops.length; i++) {
            final op = ops[i];
            final insert = op['insert'];
            if (insert is Map && insert['image'] is String) {
              final src = insert['image'] as String;
              List<int>? bytes;
              String? mimeType;
              if (src.startsWith('data:')) {
                final comma = src.indexOf(',');
                if (comma > 0) {
                  final header = src.substring(5, comma);
                  final b64 = src.substring(comma + 1);
                  bytes = base64Decode(b64);
                  mimeType = header.split(';').first;
                }
              } else if (src.startsWith('file://') || _isAbsolutePath(src)) {
                final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
                final file = File(filePath);
                if (await file.exists()) {
                  bytes = await file.readAsBytes();
                  mimeType = mime.lookupMimeType(filePath) ?? 'image/png';
                }
              }

              if (bytes != null && mimeType != null) {
                String ext;
                switch (mimeType) {
                  case 'image/jpeg': ext = 'jpg'; break;
                  case 'image/png': ext = 'png'; break;
                  case 'image/gif': ext = 'gif'; break;
                  case 'image/webp': ext = 'webp'; break;
                  default: ext = 'bin';
                }
                authed ??= await ensureClient();
                if (authed == null) break;
                final clientName = (afterTask['projects']?['clients']?['name'] ?? 'Cliente').toString();
                final projectName = (afterTask['projects']?['name'] ?? 'Projeto').toString();
                final taskTitle = (afterTask['title'] ?? 'Tarefa').toString();
                final taskId = widget.initial!['id'] as String;

                // Determine original filename
                String originalName;
                if (src.startsWith('file://') || _isAbsolutePath(src)) {
                  final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
                  originalName = filePath.split(RegExp(r'[\\/]')).last;
                  if (originalName.contains('__')) {
                    originalName = originalName.split('__').last;
                  }
                  if (!originalName.contains('.')) {
                    originalName = '$originalName.$ext';
                  }
                  if (!originalName.toLowerCase().startsWith('briefing_')) {
                    originalName = 'Briefing_$originalName';
                  } else {
                    originalName = 'Briefing_${originalName.substring('briefing_'.length)}';
                  }
                } else {
                  originalName = 'Briefing_image.$ext';
                }
                final filename = uniqueBriefingName(originalName);
                final up = await _drive.uploadToTaskSubfolder(
                  client: authed,
                  clientName: clientName,
                  projectName: projectName,
                  taskName: taskTitle,
                  subfolderName: 'Briefing',
                  filename: filename,
                  bytes: bytes,
                  mimeType: mimeType,
                );
                await _filesRepo.saveFile(
                  taskId: taskId,
                  filename: filename,
                  sizeBytes: bytes.length,
                  mimeType: mimeType,
                  driveFileId: up.id,
                  driveFileUrl: up.publicViewUrl,
                  category: 'briefing',
                );
                op['insert'] = { 'image': up.publicViewUrl };
                ops[i] = op;
              }
            }
          }
        } catch (e) {
          // Old Quill image processing - no longer needed
        }
        */

        // Save linked products to task_products table
        // Save linked products to task_products table
        try {
          final taskId = widget.initial!['id'] as String;
          await TaskProductsService.saveLinkedProducts(
            taskId: taskId,
            linkedProducts: _linkedProducts,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return StandardDialog(
      title: isEdit ? 'Editar Tarefa' : 'Nova Tarefa',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextOnlyButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          label: 'Cancelar',
        ),
        PrimaryButton(
          onPressed: _saving
              ? null
              : () {
                  _save();
                },
          label: 'Salvar',
          isLoading: _saving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Título (largura fill)
            MentionTextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o título' : null,
              maxLines: 1,
              onMentionsChanged: (userIds) {
                // Menções serão salvas ao salvar a tarefa
              },
            ),
            const SizedBox(height: 12),

            // 2. Data de conclusão / Prioridade (wrap responsivo)
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth > 264
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth.clamp(120.0, double.infinity),
                      child: TaskDateField(
                        dueDate: _dueDate,
                        onDateChanged: (date) {
                          setState(() => _dueDate = date);
                        },
                        enabled: !_saving,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth.clamp(120.0, double.infinity),
                      child: TaskPriorityField(
                        priority: _priority,
                        onPriorityChanged: (priority) {
                          setState(() => _priority = priority);
                        },
                        enabled: !_saving,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. Responsáveis (largura fill - múltiplos)
            TaskAssigneesField(
              assigneeUserIds: _assigneeUserIds,
              members: _members,
              onAssigneesChanged: (userIds) {
                setState(() => _assigneeUserIds = userIds);
              },
              enabled: !_saving,
            ),
            const SizedBox(height: 12),

            // 4. Produtos (vínculo via diálogo + cards)
            TaskProductLinkSelector(
              projectId: _projectId,
              currentTaskId: widget.initial != null
                  ? (widget.initial!['id'] as String?)
                  : null,
              selectedProducts: _linkedProducts,
              onChanged: (products) {
                setState(() => _linkedProducts = products);
              },
              enabled: !_saving,
              placeholderText: 'Vincular produto',
            ),
            const SizedBox(height: 12),

            // 5. Briefing (largura fill)
            TaskBriefingSection(
              initialJson: _briefingJson.isNotEmpty ? _briefingJson : null,
              initialText: _briefingJson.isEmpty ? _briefingText : null,
              onChanged: (text) {
                setState(() => _briefingText = text);
              },
              onJsonChanged: (json) {
                setState(() => _briefingJson = json);
              },
              enabled: !_saving,
              taskId: widget.initial?['id'] as String?,
              taskTitle: _title.text.isNotEmpty ? _title.text : 'Nova Tarefa',
              projectName: _projectName,
              clientName: _clientName,
            ),
            const SizedBox(height: 16),

            // 6. Assets (largura fill)
            TaskAssetsSection(
              taskId: widget.initial?['id'] as String? ??
                  _provisionalTaskId, // UUID provisório para tasks novas
              assetsImages: _assetsImages,
              assetsFiles: _assetsFiles,
              assetsVideos: _assetsVideos,
              onAssetsChanged: (images, files, videos) {
                setState(() {
                  _assetsImages = images;
                  _assetsFiles = files;
                  _assetsVideos = videos;
                });
              },
              enabled: !_saving,
              companyId: _companyId, // Habilita Design Materials se disponível
              companyName: _companyName, // Nome para exibir no dialog
              designMaterialsRefs:
                  _designMaterialsRefs, // Referências em memória
              onDesignMaterialsRefsChanged: (refs) {
                setState(() => _designMaterialsRefs = refs);
              },
            ),
            const SizedBox(height: 16),

            // 7. Histórico (largura fill)
            if (widget.initial != null && widget.initial!['id'] != null) ...[
              ExpansionTile(
                leading: const Icon(Icons.history),
                title: const Text('Histórico de Alterações'),
                initiallyExpanded: false,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: TaskHistoryWidget(
                        taskId: widget.initial!['id'] as String),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog para criar/editar Sub Task
/// Igual ao QuickTaskForm mas sem a opção de vincular produto
class SubTaskFormDialog extends StatefulWidget {
  final String projectId;
  final String parentTaskId;
  final String? parentTaskTitle;
  final Map<String, dynamic>? initial;

  const SubTaskFormDialog({
    super.key,
    required this.projectId,
    required this.parentTaskId,
    this.parentTaskTitle,
    this.initial,
  });

  @override
  State<SubTaskFormDialog> createState() => _SubTaskFormDialogState();
}

class _SubTaskFormDialogState extends State<SubTaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _briefingText = '';
  String _briefingJson = '';
  bool _saving = false;

  List<String> _assigneeUserIds = []; // múltiplos responsáveis
  String _status = 'todo';
  String _priority = 'medium';
  DateTime? _dueDate;

  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = true;

  // Attachments
  List<PlatformFile> _assetsImages = [];
  List<PlatformFile> _assetsFiles = [];
  // Vínculo de produtos
  List<Map<String, dynamic>> _linkedProducts = [];

  List<PlatformFile> _assetsVideos = [];

  // Informações para Google Drive (briefing images)
  String? _projectName;
  String? _clientName;
  String? _companyName;
  String? _companyId; // Para Design Materials

  // UUID provisório para subtasks novas (permite adicionar Design Materials antes de salvar)
  late final String _provisionalTaskId;

  // Referências de Design Materials (armazenadas em memória até salvar)
  List<Map<String, dynamic>> _designMaterialsRefs = [];

  final _drive = GoogleDriveOAuthService();

  @override
  void initState() {
    super.initState();

    // Gerar UUID provisório para subtasks novas
    _provisionalTaskId = const Uuid().v4();

    _loadMembers();
    _loadProjectAndClientInfo();

    // Carregar produtos vinculados quando em modo de edi e7 e3o
    final initialId = widget.initial?['id'] as String?;
    if (initialId != null && initialId.isNotEmpty) {
      TaskProductsService.loadLinkedProducts(initialId,
              projectId: widget.projectId)
          .then((list) {
        if (mounted) setState(() => _linkedProducts = list);
      });
    }

    // Initialize briefing from description
    if (widget.initial != null && widget.initial!['description'] != null) {
      final d = widget.initial!['description'] as String;
      // Try to parse as JSON first (AppFlowy format)
      try {
        final parsed = jsonDecode(d);
        if (parsed is Map) {
          _briefingJson = d;
        } else {
          _briefingText = d;
        }
      } catch (_) {
        // If not JSON, treat as plain text
        _briefingText = d;
      }
    }

    if (widget.initial != null) {
      _title.text = widget.initial!['title'] ?? '';

      // Carregar responsáveis (suporta assigned_to antigo e assignee_user_ids novo)
      final assigneeUserIds = widget.initial!['assignee_user_ids'] as List?;
      if (assigneeUserIds != null && assigneeUserIds.isNotEmpty) {
        _assigneeUserIds = assigneeUserIds.cast<String>();
      } else {
        final assignedTo = widget.initial!['assigned_to'] as String?;
        _assigneeUserIds = assignedTo != null ? [assignedTo] : [];
      }

      _status = widget.initial!['status'] ?? 'todo';
      _priority = widget.initial!['priority'] ?? 'medium';

      final dueDateStr = widget.initial!['due_date'];
      if (dueDateStr != null) {
        try {
          _dueDate = DateTime.parse(dueDateStr);
        } catch (e) {
          _dueDate = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      // Buscar membros do projeto primeiro
      final res = await Supabase.instance.client
          .from('project_members')
          .select(
              'user_id, profiles:user_id(full_name, email, role, avatar_url)')
          .eq('project_id', widget.projectId);
      final all = List<Map<String, dynamic>>.from(res);

      // Não filtrar por roles - mostrar todos os membros do projeto
      var filtered = all;

      // Fallback: buscar membros da organização se o projeto não tem membros
      if (filtered.isEmpty) {
        final orgId = OrganizationContext.currentOrganizationId;

        if (orgId != null) {
          try {
            final orgMembers = await Supabase.instance.client.rpc(
              'get_organization_members_with_profiles',
              params: {'org_id': orgId},
            ) as List;

            filtered = orgMembers.map((m) {
              final member = m as Map<String, dynamic>;
              return {
                'user_id': member['user_id'],
                'profiles': {
                  'id': member['user_id'],
                  'full_name': member['full_name'],
                  'email': member['email'],
                  'avatar_url': member['avatar_url'],
                  'role': member['role'],
                },
              };
            }).toList();
          } catch (e) {
            // Silently fail - filtered will remain empty
          }
        }
      }

      if (mounted) {
        setState(() {
          _members = filtered;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _members = [];
          _loadingMembers = false;
        });
      }
    }
  }

  Future<void> _loadProjectAndClientInfo() async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select(
              'name, client_id, company_id, clients:client_id(name), companies:company_id(name)')
          .eq('id', widget.projectId)
          .maybeSingle();

      if (project != null && mounted) {
        setState(() {
          _projectName = project['name'] as String?;
          _clientName = (project['clients'] as Map?)?['name'] as String?;
          _companyName = (project['companies'] as Map?)?['name'] as String?;
          _companyId =
              project['company_id'] as String?; // Para Design Materials
        });
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      // Validar prioridade
      final validPriorities = ['low', 'medium', 'high', 'urgent'];
      final safePriority =
          validPriorities.contains(_priority) ? _priority : 'medium';

      // Validar status
      final validStatuses = [
        'todo',
        'in_progress',
        'review',
        'completed',
        'cancelled'
      ];
      final safeStatus = validStatuses.contains(_status) ? _status : 'todo';

      final data = {
        'title': _title.text.trim(),
        'description': _briefingJson.isNotEmpty
            ? _briefingJson
            : (_briefingText.isNotEmpty ? _briefingText : null),
        'project_id': widget.projectId,
        'parent_task_id': widget.parentTaskId,
        'assigned_to':
            _assigneeUserIds.isNotEmpty ? _assigneeUserIds.first : null,
        'assignee_user_ids': _assigneeUserIds,
        'status': safeStatus,
        'priority': safePriority,
        'due_date': _dueDate == null
            ? null
            : DateUtils.dateOnly(_dueDate!).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.initial == null) {
        // Criar nova sub task usando o módulo (isso vai criar a pasta no Google Drive)
        // Usar UUID provisório para permitir referências de Design Materials
        final createdTask = await tasksModule.createTask(
          id: _provisionalTaskId, // UUID provisório gerado no initState
          title: data['title'] as String,
          description: data['description'] as String?,
          projectId: widget.projectId,
          assignedTo:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds.first : null,
          assigneeUserIds:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds : null,
          status: (data['status'] ?? 'todo') as String,
          priority: (data['priority'] ?? 'medium') as String,
          dueDate: data['due_date'] != null
              ? DateTime.parse(data['due_date'] as String)
              : null,
          parentTaskId: widget.parentTaskId,
        );

        final taskId = createdTask['id'] as String;

        // Salvar referências de Design Materials (se houver)
        if (_designMaterialsRefs.isNotEmpty) {
          for (final ref in _designMaterialsRefs) {
            try {
              await client.from('task_files').insert({
                'task_id': taskId,
                'filename': ref['filename'],
                'drive_file_id': ref['drive_file_id'],
                'drive_file_url': ref['drive_file_url'],
                'mime_type': ref['mime_type'],
                'size_bytes': ref[
                    'file_size_bytes'], // Coluna é 'size_bytes', não 'file_size_bytes'
                'category': 'assets',
                'created_by': userId,
              });
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
          }
        }

        // Upload de imagens do briefing em BACKGROUND (não bloqueia o salvamento)
        if (_clientName != null &&
            _projectName != null &&
            widget.parentTaskTitle != null) {
          startBriefingImagesBackgroundUpload(
            taskId: taskId,
            briefingJson: _briefingJson,
            clientName: _clientName!,
            projectName: _projectName!,
            taskTitle: _title.text.trim().isNotEmpty
                ? _title.text.trim()
                : 'Sub Tarefa',
            companyName: _companyName,
            isSubTask: true,
            parentTaskTitle: widget.parentTaskTitle,
          );
        }

        // Salvar vnculos de produtos da Subtarefa (criafo)
        await TaskProductsService.saveLinkedProducts(
          taskId: taskId,
          linkedProducts: _linkedProducts,
        );

        // Upload Assets em segundo plano (se houver) - SUBTASK
        if (_clientName != null &&
            _projectName != null &&
            widget.parentTaskTitle != null) {
          await startAssetsBackgroundUpload(
            taskId: taskId,
            clientName: _clientName!,
            projectName: _projectName!,
            taskTitle: _title.text.trim().isNotEmpty
                ? _title.text.trim()
                : 'Sub Tarefa',
            assetsImages: _assetsImages,
            assetsFiles: _assetsFiles,
            assetsVideos: _assetsVideos,
            companyName: _companyName,
            isSubTask: true,
            parentTaskTitle: widget.parentTaskTitle,
            context: mounted ? context : null,
            driveService: _drive,
          );
        }
      } else {
        // Atualizar sub task existente usando o módulo (isso vai renomear a pasta no Google Drive se necessário)
        await tasksModule.updateTask(
          taskId: widget.initial!['id'],
          title: data['title'] as String?,
          description: data['description'] as String?,
          assignedTo:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds.first : null,
          assigneeUserIds:
              _assigneeUserIds.isNotEmpty ? _assigneeUserIds : null,
          status: data['status'] as String?,
          priority: data['priority'] as String?,
          dueDate: data['due_date'] != null
              ? DateTime.parse(data['due_date'] as String)
              : null,
        );

        // Salvar vnculos de produtos da Subtarefa (edie7fo)
        await TaskProductsService.saveLinkedProducts(
          taskId: widget.initial!['id'] as String,
          linkedProducts: _linkedProducts,
        );

        // Upload Assets em segundo plano (se houver) - SUBTASK EDIT
        if (_clientName != null &&
            _projectName != null &&
            widget.parentTaskTitle != null) {
          await startAssetsBackgroundUpload(
            taskId: widget.initial!['id'] as String,
            clientName: _clientName!,
            projectName: _projectName!,
            taskTitle: _title.text.trim().isNotEmpty
                ? _title.text.trim()
                : 'Sub Tarefa',
            assetsImages: _assetsImages,
            assetsFiles: _assetsFiles,
            assetsVideos: _assetsVideos,
            companyName: _companyName,
            isSubTask: true,
            parentTaskTitle: widget.parentTaskTitle,
            context: mounted ? context : null,
            driveService: _drive,
          );
        }
      }

      // Atualizar o projeto também (updated_by e updated_at)
      try {
        await client.from('projects').update({
          'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.projectId);
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }

      // Atualizar o status da task principal (aguardando/concluída)
      try {
        await tasksModule.updateTaskStatus(widget.parentTaskId);
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return StandardDialog(
      title: isEdit ? 'Editar Subtarefa' : 'Nova Subtarefa',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextOnlyButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          label: 'Cancelar',
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          label: 'Salvar',
          isLoading: _saving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Título (largura fill)
            MentionTextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o título' : null,
              maxLines: 1,
              onMentionsChanged: (userIds) {
                // Menções serão salvas ao salvar a tarefa
              },
            ),
            const SizedBox(height: 12),

            // 2. Data de conclusão / Prioridade (wrap responsivo)
            if (_loadingMembers)
              const Center(child: CircularProgressIndicator())
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth > 264
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth.clamp(120.0, double.infinity),
                        child: TaskDateField(
                          dueDate: _dueDate,
                          onDateChanged: (date) {
                            setState(() => _dueDate = date);
                          },
                          enabled: !_saving,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth.clamp(120.0, double.infinity),
                        child: TaskPriorityField(
                          priority: _priority,
                          onPriorityChanged: (priority) {
                            setState(() => _priority = priority);
                          },
                          enabled: !_saving,
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),

            // 3. Status (largura fill)
            if (!_loadingMembers)
              TaskStatusField(
                status: _status,
                taskId: widget.initial?['id'] as String?,
                onStatusChanged: (status) {
                  setState(() => _status = status);
                },
                enabled: !_saving,
              ),
            const SizedBox(height: 12),

            // 4. Responsáveis (largura fill - múltiplos)
            if (!_loadingMembers)
              TaskAssigneesField(
                assigneeUserIds: _assigneeUserIds,
                members: _members,
                onAssigneesChanged: (userIds) {
                  setState(() => _assigneeUserIds = userIds);
                },
                enabled: !_saving,
              ),
            const SizedBox(height: 16),
            // 5. Produtos (vínculo)
            TaskProductLinkSelector(
              projectId: widget.projectId,
              currentTaskId: widget.initial != null
                  ? (widget.initial!['id'] as String?)
                  : null,
              selectedProducts: _linkedProducts,
              onChanged: (products) {
                setState(() => _linkedProducts = products);
              },
              enabled: !_saving,
              placeholderText: 'Vincular produto',
            ),
            const SizedBox(height: 16),

            // 5. Briefing (largura fill)
            TaskBriefingSection(
              initialJson: _briefingJson.isNotEmpty ? _briefingJson : null,
              initialText: _briefingJson.isEmpty ? _briefingText : null,
              onChanged: (text) {
                setState(() => _briefingText = text);
              },
              onJsonChanged: (json) {
                setState(() => _briefingJson = json);
              },
              enabled: !_saving,
              taskId: widget.initial?['id'] as String?,
              taskTitle: _title.text.isNotEmpty ? _title.text : 'Nova Tarefa',
              projectName: _projectName,
              clientName: _clientName,
            ),
            const SizedBox(height: 16),

            // 6. Assets (largura fill)
            TaskAssetsSection(
              taskId: widget.initial?['id'] as String? ??
                  _provisionalTaskId, // UUID provisório para subtasks novas
              assetsImages: _assetsImages,
              assetsFiles: _assetsFiles,
              assetsVideos: _assetsVideos,
              onAssetsChanged: (images, files, videos) {
                setState(() {
                  _assetsImages = images;
                  _assetsFiles = files;
                  _assetsVideos = videos;
                });
              },
              enabled: !_saving,
              companyId: _companyId, // Habilita Design Materials se disponível
              companyName: _companyName, // Nome para exibir no dialog
              designMaterialsRefs:
                  _designMaterialsRefs, // Referências em memória
              onDesignMaterialsRefsChanged: (refs) {
                setState(() => _designMaterialsRefs = refs);
              },
            ),
            const SizedBox(height: 16),

            // 7. Histórico (largura fill)
            if (widget.initial != null && widget.initial!['id'] != null) ...[
              ExpansionTile(
                leading: const Icon(Icons.history),
                title: const Text('Histórico de Alterações'),
                initiallyExpanded: false,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: TaskHistoryWidget(
                        taskId: widget.initial!['id'] as String),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
