import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestor_projetos_flutter/src/utils/money.dart';
import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';
import 'package:gestor_projetos_flutter/widgets/tabs/tabs.dart';
import 'package:gestor_projetos_flutter/modules/projects/module.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';
import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

import '../../state/app_state_scope.dart';
import 'widgets/project_status_field.dart';

class ProjectFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initial; // null = criar
  final String? fixedClientId; // quando vindo de Cliente > Projeto
  final String? fixedCompanyId; // quando vindo de Empresa > Projeto
  const ProjectFormDialog({super.key, this.initial, this.fixedClientId, this.fixedCompanyId});

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _descriptionText = ''; // Texto da descrição (plain text)
  String _descriptionJson = ''; // JSON da descrição (rich text - AppFlowy Editor)
  final _valueText = TextEditingController();
  bool _projectValueOverridden = false;
  String _currencyCode = 'BRL'; // BRL | USD | EUR
  String _status = 'not_started'; // Status do projeto
  String? _clientId; // usado quando fixedClientId == null
  String? _companyId; // usado para associar projeto à empresa
  bool _saving = false;

  // Custos adicionais
  final List<_CostItem> _costs = [];

  // Itens do catálogo
  final List<_CatalogItem> _catalogItems = [];
  // Cache de produtos por pacote: packageId -> lista de itens {name, qty, thumbUrl, productId, comment}
  final Map<String, List<Map<String, dynamic>>> _packageProductsById = {};

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _clientId = widget.fixedClientId;
    _companyId = widget.fixedCompanyId;

    // Inicializar descrição (carregar JSON se existir, senão texto plano)
    _descriptionJson = i != null ? (i['description_json'] ?? '').toString() : '';
    _descriptionText = i != null ? (i['description'] ?? '').toString() : '';

    if (i != null) {
      _name.text = (i['name'] ?? '').toString();
      final vc = i['value_cents'] as int?;
      if (vc != null) _valueText.text = _formatCents(vc).replaceAll('.', ',');
      final cur = i['currency_code'] as String?;
      if (cur != null && ['BRL', 'USD', 'EUR'].contains(cur)) _currencyCode = cur;
      // Inicializar status (normalizar status antigos)
      final status = (i['status'] ?? 'not_started').toString();
      if (status == 'active' || status == 'ativo') {
        _status = 'in_progress';
      } else if (status == 'inactive' || status == 'inativo') {
        _status = 'paused';
      } else {
        _status = status;
      }
      _clientId ??= i['client_id'] as String?;
      _companyId ??= i['company_id'] as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadAdditionalCosts(i['id'] as String);
        await _loadCatalogItems(i['id'] as String);
        if (!mounted) return;
        setState(() {
          // Só preenche automaticamente quando o valor do projeto está zerado e o usuário ainda não alterou manualmente
          if (!_projectValueOverridden && _projectValueCents == 0 && _catalogItems.isNotEmpty) {
            _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
          }
        });
      });
    }
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
  }

  Future<void> _loadCatalogItems(String projectId) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('project_catalog_items')
          .select('kind, item_id, name, currency_code, unit_price_cents, quantity, position, comment')
          .eq('project_id', projectId)
          .order('position', ascending: true, nullsFirst: true);

      final list = List<Map<String, dynamic>>.from(rows as List? ?? []);
      final productIds = <String>{};
      final packageIds = <String>{};
      for (final m in list) {
        final kind = (m['kind'] as String?) ?? 'product';
        final id = (m['item_id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (kind == 'product') {
          productIds.add(id);
        } else if (kind == 'package') {
          packageIds.add(id);
        }
      }

      final Map<String, String?> thumbByKey = {};
      // Buscar thumbs de produtos
      for (final pid in productIds) {
        try {
          final p = await client
              .from('products')
              .select('id, image_thumb_url, image_url')
              .eq('id', pid)
              .maybeSingle();
          if (p != null) {
            final url = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
            thumbByKey['product:$pid'] = url;
          }
        } catch (_) {}
      }
      // Buscar thumbs de pacotes
      for (final pkgId in packageIds) {
        try {
          final p = await client
              .from('packages')
              .select('id, image_thumb_url, image_url')
              .eq('id', pkgId)
              .maybeSingle();
          if (p != null) {
            final url = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
            thumbByKey['package:$pkgId'] = url;
          }
        } catch (_) {}
      }

      setState(() {
        _catalogItems.clear();
        for (final m in list) {
          final kind = (m['kind'] as String?) ?? 'product';
          final id = (m['item_id'] ?? '').toString();
          final key = '$kind:$id';
          final thumb = thumbByKey[key];
          _catalogItems.add(_CatalogItem(
            itemType: kind,
            itemId: id,
            name: (m['name'] as String?) ?? '-',
            currency: (m['currency_code'] as String?) ?? _currencyCode,
            priceCents: (m['unit_price_cents'] as int?) ?? 0,
            thumbUrl: thumb,
            comment: (m['comment'] as String?),
          ));
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _valueText.dispose();
    for (final c in _costs) { c.dispose(); }
    super.dispose();
  }

  // Utils dinheiro
  int _parseMoneyToCents(String input) {
    return Money.parseToCents(input);
  }
  Future<void> _loadPackageProductsFor(String packageId) async {
    try {
      final rows = await Supabase.instance.client
          .from('package_items')
          .select('quantity, comment, position, products:product_id(id, name, image_url, image_thumb_url)')
          .eq('package_id', packageId)
          .order('position', ascending: true, nullsFirst: true);
      final list = <Map<String, dynamic>>[];
      var i = 0;
      for (final r in rows as List<dynamic>) {
        final m = r as Map<String, dynamic>;
        final prod = (m['products'] as Map?)?.cast<String, dynamic>();
        list.add({
          'productId': (prod?['id'] as String?) ?? '',
          'name': (prod?['name'] as String?) ?? '-',
          'qty': (m['quantity'] as int?) ?? 1,
          'thumbUrl': (prod?['image_thumb_url'] as String?) ?? (prod?['image_url'] as String?),
          'comment': (m['comment'] as String?),
          'pos': (m['position'] as int?) ?? i,
        });
        i++;
      }
      // Overlay: comentários específicos deste projeto, se houver um projeto em edição
      final projectId = (widget.initial?['id'] ?? '').toString();
      if (projectId.isNotEmpty) {
        try {
          final rows = await Supabase.instance.client
              .from('project_package_item_comments')
              .select('product_id, position, comment')
              .eq('project_id', projectId)
              .eq('package_id', packageId);
          final overrides = List<Map<String, dynamic>>.from(rows);
          for (final k in list) {
            final pid = (k['productId'] as String?) ?? '';
            final pos = (k['pos'] as int?) ?? 0;
            if (pid.isEmpty) continue;
            final m = overrides.firstWhere(
              (o) => (o['product_id'] ?? '').toString() == pid && ((o['position'] as int?) ?? -1) == pos,
              orElse: () => const {},
            );
            final oc = (m['comment'] as String?);
            if (oc != null && oc.isNotEmpty) k['comment'] = oc;
          }
        } catch (_) {}
      }
      setState(() { _packageProductsById[packageId] = list; });
    } catch (e) {
      setState(() { _packageProductsById[packageId] = const []; });
    }
  }


  String _formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    return '$sign${Money.formatCents(cents.abs())}';
  }

  String _currencySymbol(String code) {
    return Money.symbol(code);
  }

  Future<void> _repriceCatalogItemsForCurrency(String currency) async {
    try {
      final client = Supabase.instance.client;
      final productIds = _catalogItems.where((e) => e.itemType == 'product').map((e) => e.itemId).toSet().toList();
      final packageIds = _catalogItems.where((e) => e.itemType == 'package').map((e) => e.itemId).toSet().toList();

      final Map<String, int> productPrices = {};
      final Map<String, int> packagePrices = {};

      if (productIds.isNotEmpty) {
        for (final pid in productIds) {
          final m = await client
              .from('products')
              .select('id, price_map, currency_code, price_cents')
              .eq('id', pid)
              .maybeSingle();
          if (m == null) continue;
          final pm = (m['price_map'] as Map?)?.cast<String, dynamic>();
          int cents = 0;
          if (pm != null && pm[currency] is int) {
            cents = pm[currency] as int;
          } else if ((m['currency_code'] as String?) == currency) {
            cents = (m['price_cents'] as int?) ?? 0;
          }
          productPrices[pid] = cents;
        }
      }

      if (packageIds.isNotEmpty) {
        for (final pkgId in packageIds) {
          final m = await client
              .from('packages')
              .select('id, price_map, currency_code, price_cents')
              .eq('id', pkgId)
              .maybeSingle();
          if (m == null) continue;
          final pm = (m['price_map'] as Map?)?.cast<String, dynamic>();
          int cents = 0;
          if (pm != null && pm[currency] is int) {
            cents = pm[currency] as int;
          } else if ((m['currency_code'] as String?) == currency) {
            cents = (m['price_cents'] as int?) ?? 0;
          }
          packagePrices[pkgId] = cents;
        }
      }

      setState(() {
        _catalogItems.asMap().forEach((idx, it) {
          int newPrice = it.priceCents;
          if (it.itemType == 'product') {
            newPrice = productPrices[it.itemId] ?? 0;
          } else if (it.itemType == 'package') {
            newPrice = packagePrices[it.itemId] ?? 0;
          }
          _catalogItems[idx] = it.copyWith(priceCents: newPrice, currency: currency);
        });
      });
    } catch (e) {
      debugPrint('Falha ao reprecificar itens para $currency: $e');
    }
  }

  int get _projectValueCents => _parseMoneyToCents(_valueText.text);

  int get _catalogSumCents => _catalogItems.where((it) => it.currency == _currencyCode).fold<int>(0, (sum, it) => sum + it.priceCents);
  int get _additionalCostsSumCents => _costs.fold<int>(0, (sum, c) => sum + _parseMoneyToCents(c.valueController.text));

  int get _autoTotalCents => _catalogSumCents + _additionalCostsSumCents;



  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.fixedClientId == null && (_clientId == null || _clientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um cliente')));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final descPlainText = _descriptionText.trim();
      final descJson = _descriptionJson.trim();
      final base = <String, dynamic>{
        'name': _name.text.trim(),
        'description': descPlainText.isEmpty ? null : descPlainText,
        'description_json': descJson.isEmpty ? null : descJson, // Salvar JSON do rich text
        'currency_code': _currencyCode,
        'value_cents': (_projectValueCents > 0 ? _projectValueCents : _autoTotalCents),
      };
      String? projectId;
      if (widget.initial == null) {
        final payload = {
          ...base,
          'client_id': widget.fixedClientId ?? _clientId,
          'company_id': _companyId,
          'owner_id': uid,
          'status': _status,
          if (uid != null) 'created_by': uid,
          if (uid != null) 'updated_by': uid,
        };
        final inserted = await client.from('projects').insert(payload).select('id').maybeSingle();
        projectId = (inserted?['id'] ?? '').toString();
      } else {
        projectId = (widget.initial!['id'] ?? '').toString();
        final payload = {
          ...base,
          'company_id': _companyId,
          'status': _status,
          if (uid != null) 'updated_by': uid,
          'updated_at': DateTime.now().toIso8601String(),
        };
        // Usar o módulo para atualizar o projeto (isso vai renomear a pasta no Google Drive se necessário)
        await projectsModule.updateProject(
          projectId: projectId,
          updates: payload,
        );
      }
      if (projectId.isNotEmpty) {
        // Replace custos adicionais de forma isolada
        try {
          await client.from('project_additional_costs').delete().eq('project_id', projectId);
          if (_costs.isNotEmpty) {
            final rows = _costs.map((c) => {
                  'project_id': projectId,
                  'description': c.descController.text.trim().isEmpty ? null : c.descController.text.trim(),
                  'amount_cents': _parseMoneyToCents(c.valueController.text),
                  'currency_code': _currencyCode,
                  if (uid != null) 'created_by': uid,
                }).toList();
            if (rows.isNotEmpty) {
              await client.from('project_additional_costs').insert(rows);
            }
          }
        } catch (e) {
          debugPrint('Falha ao salvar custos adicionais: $e');
          // Prosseguir mesmo que custos adicionais falhem
        }
        if (_catalogItems.isNotEmpty) {
          final rows = _catalogItems.asMap().entries.map((e) { final idx = e.key; final it = e.value; return {
                'project_id': projectId,
                'kind': it.itemType,
                'item_id': it.itemId,
                'name': it.name,
                'currency_code': it.currency,
                'unit_price_cents': it.priceCents,
                'quantity': 1,
                'comment': (it.comment?.trim().isEmpty ?? true) ? null : it.comment!.trim(),
                'position': idx,
                if (uid != null) 'created_by': uid,
              }; }).toList();
          try {
            // Replace itens do catálogo deste projeto
            await client.from('project_catalog_items').delete().eq('project_id', projectId);
            await client.from('project_catalog_items').insert(rows);
          } catch (e) {
            // Fallback: se a coluna 'comment' não existir, remove e tenta novamente
            final msg = e.toString();
            final looksLikeMissingColumn = msg.contains('comment') || msg.contains('column') || msg.contains('PGRST204');
            if (looksLikeMissingColumn) {
              final sanitized = rows.map((r) {
                final m = Map<String, dynamic>.from(r);
                // Apenas remove 'comment' se for coluna ausente
                m.remove('comment');
                // Mantém 'kind' para não violar NOT NULL
                return m;
              }).toList();
              await client.from('project_catalog_items').insert(sanitized);
            } else {
              rethrow;
            }
          }

          // Persistir comentários de produtos de pacotes, se houver
          // Comentários por ocorrência (project_id, package_id, product_id, position)
          final ppic = <Map<String, dynamic>>[];
          for (final pkg in _catalogItems.where((e) => e.itemType == 'package')) {
            final kids = _packageProductsById[pkg.itemId] ?? const [];
            for (final k in kids) {
              final pid = (k['productId'] as String?) ?? '';
              final pos = (k['pos'] as int?) ?? 0;
              final cmt = (k['comment'] as String?)?.trim();
              if (pid.isEmpty || cmt == null || cmt.isEmpty) continue;
              ppic.add({
                'project_id': projectId,
                'package_id': pkg.itemId,
                'product_id': pid,
                'position': pos,
                'comment': cmt,
                if (uid != null) 'created_by': uid,
              });
            }
          }
          if (ppic.isNotEmpty) {
            try {
              await client.from('project_package_item_comments').upsert(ppic, onConflict: 'project_id,package_id,product_id,position');
            } catch (e) {
              final msg = e.toString();
              final looksMissingPosition = msg.contains('position') || msg.contains('column') || msg.contains('PGRST204');
              try {
                // Fallback: remover coluna 'position' do payload e do onConflict se não existir
                if (looksMissingPosition) {
                  final ppicNoPos = ppic.map((r) {
                    final m = Map<String, dynamic>.from(r);
                    m.remove('position');
                    return m;
                  }).toList();
                  try {
                    await client.from('project_package_item_comments').upsert(ppicNoPos, onConflict: 'project_id,package_id,product_id');
                  } catch (_) {
                    // Nova tentativa: replace manual
                    final pkgIds = ppicNoPos.map((r) => (r['package_id'] ?? '').toString()).toSet();
                    for (final pkgId in pkgIds) {
                      await client.from('project_package_item_comments')
                          .delete()
                          .eq('project_id', projectId)
                          .eq('package_id', pkgId);
                    }
                    await client.from('project_package_item_comments').insert(ppicNoPos);
                  }
                } else {
                  // Fallback para ambientes sem suporte onConflict ou outros conflitos
                  final pkgIds = ppic.map((r) => (r['package_id'] ?? '').toString()).toSet();
                  for (final pkgId in pkgIds) {
                    await client.from('project_package_item_comments')
                        .delete()
                        .eq('project_id', projectId)
                        .eq('package_id', pkgId);
                  }
                  await client.from('project_package_item_comments').insert(ppic);
                }
              } catch (_) {
                rethrow;
              }
            }
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erro ao salvar projeto: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar projeto: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEditFinancial = appState.isAdmin || appState.isFinanceiro; // controla edição
    final isEdit = widget.initial != null;

    return StandardDialog(
      title: isEdit ? 'Editar Projeto' : 'Novo Projeto',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      showCloseButton: false,
      isLoading: _saving,
      actions: _buildActions(canEditFinancial),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                    if (widget.fixedClientId == null)
                      AsyncDropdownField<String>(
                        value: _clientId,
                        loadItems: () async {
                          final rows = await Supabase.instance.client
                              .from('clients')
                              .select('id, name')
                              .order('name');
                          return (rows as List).map((item) => SearchableDropdownItem(
                            value: item['id'] as String,
                            label: (item['name'] ?? '-') as String,
                          )).toList();
                        },
                        onChanged: (v) {
                          setState(() {
                            _clientId = v;
                            _companyId = null;
                          });
                        },
                        labelText: 'Cliente',
                        emptyMessage: 'Nenhum cliente cadastrado',
                        width: 300,
                      ),
                    if (widget.fixedClientId == null) const SizedBox(height: 12),
                    if (widget.fixedCompanyId == null)
                      AsyncDropdownField<String>(
                        value: _companyId,
                        loadItems: () async {
                          if (_clientId == null) return [];
                          final rows = await Supabase.instance.client
                              .from('companies')
                              .select('id, name')
                              .eq('client_id', _clientId!)
                              .order('name');
                          return (rows as List).map((item) => SearchableDropdownItem(
                            value: item['id'] as String,
                            label: (item['name'] ?? '-') as String,
                          )).toList();
                        },
                        onChanged: (v) => setState(() => _companyId = v),
                        labelText: 'Empresa',
                        dependencies: [_clientId],
                        enabled: _clientId != null,
                        emptyMessage: 'Selecione um cliente primeiro',
                        width: 300,
                      ),
                    if (widget.fixedCompanyId == null) const SizedBox(height: 12),
                    GenericTextField(
                      controller: _name,
                      labelText: 'Nome *',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    // Campo de texto simples para descrição
                    GenericTextArea(
                      initialValue: _descriptionText,
                      labelText: 'Descrição',
                      hintText: 'Descrição do projeto...',
                      minLines: 3,
                      maxLines: 8,
                      enabled: !_saving,
                      onChanged: (text) {
                        setState(() {
                          _descriptionText = text;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Campo de status
                    ProjectStatusField(
                      status: _status,
                      onStatusChanged: (status) {
                        setState(() {
                          _status = status;
                        });
                      },
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 12),
                    if (_catalogItems.isNotEmpty && canEditFinancial) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 16),
                                const SizedBox(width: 4),
                                Text('${_currencySymbol(_currencyCode)} ${_formatCents(_catalogSumCents).replaceAll('.', ',')}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 16),
                                const SizedBox(width: 4),
                                Text('${_currencySymbol(_currencyCode)} ${_formatCents(_additionalCostsSumCents).replaceAll('.', ',')}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calculate_outlined, size: 16),
                                const SizedBox(width: 4),
                                Text('${_currencySymbol(_currencyCode)} ${_formatCents(_autoTotalCents).replaceAll('.', ',')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Custos adicionais
                    Row(children: [
                      if (canEditFinancial)
                        IconTextButton(onPressed: () => setState(() => _costs.add(_CostItem())), icon: Icons.add, label: 'Adicionar custo'),
                      const Spacer(),
                      Text('Custos adicionais', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    Column(children: _costs.asMap().entries.map((e) {
                      final i = e.key; final c = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(flex: 2, child: GenericTextField(controller: c.descController, enabled: canEditFinancial, labelText: 'Descrição')),
                          const SizedBox(width: 8),
                          Expanded(child: GenericNumberField(controller: c.valueController, enabled: canEditFinancial, allowDecimals: true, labelText: 'Valor', prefixText: '${_currencySymbol(_currencyCode)} ', onChanged: (_) {
                            setState(() {
                              if (!_projectValueOverridden) {
                                _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                              }
                            });
                          })),
                          const SizedBox(width: 8),
                          if (canEditFinancial)
                            IconOnlyButton(onPressed: () => setState(() => _costs.removeAt(i)), icon: Icons.delete_outline, tooltip: 'Remover'),
                        ]),
                      );
                    }).toList()),
                    const SizedBox(height: 8),
                    // Itens catálogo
                    Row(children: [
                      IconTextButton(
                        onPressed: () async {

                          final selected = await showDialog<_CatalogItem>(
                            context: context,
                            builder: (_) => _SelectCatalogItemDialog(currency: _currencyCode),
                          );
                          if (selected != null) {
                            setState(() {
                              _catalogItems.add(selected);
                              if (!_projectValueOverridden && _catalogItems.isNotEmpty) {
                                _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                              }
                            });
                          }
                        },
                        icon: Icons.shopping_cart,
                        label: 'Adicionar do Catálogo',
                      ),
                      const Spacer(),
                      Text('Itens do Catálogo', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    ReorderableDragList<_CatalogItem>(
                      items: _catalogItems,
                      enabled: true,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _catalogItems.removeAt(oldIndex);
                          _catalogItems.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, it, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              if ((it.thumbUrl ?? '').isNotEmpty)
                                ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(it.thumbUrl!, width: 40, height: 40, fit: BoxFit.cover))
                              else
                                const CircleAvatar(radius: 18, child: Icon(Icons.image_not_supported, size: 18)),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(it.name, style: Theme.of(context).textTheme.bodyLarge),
                                const SizedBox(height: 4),
                                Text(it.itemType == 'product' ? 'Produto' : 'Pacote', style: Theme.of(context).textTheme.bodySmall),
                                if ((it.comment ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(it.comment!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber)),
                                ],
                              ])),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: GenericNumberField(
                                  key: ValueKey('price_${it.itemType}_${it.itemId}_${it.currency}_${it.priceCents}'),
                                  initialValue: (it.priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ','),
                                  enabled: canEditFinancial,
                                  allowDecimals: true,
                                  labelText: 'Preço',
                                  prefixText: '${_currencySymbol(it.currency)} ',
                                  onChanged: (v) {
                                    final cents = _parseMoneyToCents(v);
                                    setState(() {
                                      _catalogItems[index] = it.copyWith(priceCents: cents);
                                      if (!_projectValueOverridden && _catalogItems.isNotEmpty) {
                                        _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconOnlyButton(
                                tooltip: 'Editar comentário',
                                icon: Icons.edit_note_outlined,
                                onPressed: () async {
                                  final text = await showDialog<String>(
                                    context: context,
                                    builder: (_) {
                                      final c = TextEditingController(text: it.comment ?? '');
                                      return StandardDialog(
                                        title: 'Comentário (${it.itemType == 'product' ? 'Produto' : 'Pacote'})',
                                        width: StandardDialog.widthSmall,
                                        height: StandardDialog.heightSmall,
                                        actions: [
                                          TextOnlyButton(onPressed: () => Navigator.pop(context), label: 'Cancelar'),
                                          PrimaryButton(onPressed: () => Navigator.pop(context, c.text), label: 'Salvar'),
                                        ],
                                        child: TextField(
                                          controller: c,
                                          maxLines: 4,
                                          decoration: const InputDecoration(hintText: 'Digite um comentário para este projeto'),
                                        ),
                                      );
                                    },
                                  );
                                  if (text != null) {
                                    setState(() { _catalogItems[index] = it.copyWith(comment: text); });
                                  }
                                },
                              ),
                              IconOnlyButton(icon: Icons.delete_outline, tooltip: 'Remover', onPressed: () => setState(() {
                                _catalogItems.removeAt(index);
                                if (!_projectValueOverridden) {
                                  _valueText.text = _catalogItems.isEmpty ? _valueText.text : _formatCents(_autoTotalCents).replaceAll('.', ',');
                                }
                              })),
                            ]),
                            if (it.itemType == 'package') ...[
                              const SizedBox(height: 6),
                              Builder(builder: (_) {
                                final kids = _packageProductsById[it.itemId];
                                if (kids == null) {
                                  _loadPackageProductsFor(it.itemId);
                                  return const SizedBox.shrink();
                                }
                                if (kids.isEmpty) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(left: 48),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Itens do pacote', style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    ...kids.map((k) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          if ((k['thumbUrl'] as String?)?.isNotEmpty == true)
                                            ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(k['thumbUrl'] as String, width: 28, height: 28, fit: BoxFit.cover))
                                          else
                                            const CircleAvatar(radius: 12, child: Icon(Icons.image_not_supported, size: 12)),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text('${k['qty']}× ${k['name']}', style: Theme.of(context).textTheme.bodySmall)),
                                          IconOnlyButton(
                                            tooltip: 'Editar comentário do produto do pacote',
                                            icon: Icons.edit_note_outlined,
                                            iconSize: 18,
                                            onPressed: () async {
                                              final text = await showDialog<String>(
                                                context: context,
                                                builder: (_) {
                                                  final c = TextEditingController(text: (k['comment'] as String?) ?? '');
                                                  return StandardDialog(
                                                    title: 'Comentário do produto (pacote)',
                                                    width: StandardDialog.widthSmall,
                                                    height: StandardDialog.heightSmall,
                                                    actions: [
                                                      TextOnlyButton(onPressed: () => Navigator.pop(context), label: 'Cancelar'),
                                                      PrimaryButton(onPressed: () => Navigator.pop(context, c.text), label: 'Salvar'),
                                                    ],
                                                    child: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'Comentário deste projeto')),
                                                  );
                                                },
                                              );
                                              if (text != null) {
                                                setState(() {
                                                  k['comment'] = text;
                                                });
                                              }
                                            },
                                          ),

                                        ]),
                                        if ((k['comment'] as String?)?.isNotEmpty == true)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 34, top: 2),
                                            child: Text(k['comment'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber)),
                                          ),
                                      ]),
                                    )),
                                  ]),
                                );
                              }),
                            ]
                          ]),
                        );
                      },
                      getKey: (it) => it.uniqueId,
                      emptyWidget: const Text('Nenhum item vinculado'),
                    ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(bool canEditFinancial) {
    return [
      // Moeda
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<String>(
          initialValue: ['BRL','USD','EUR'].contains(_currencyCode) ? _currencyCode : 'BRL',
          items: const [
            DropdownMenuItem(value: 'BRL', child: Text('Real (BRL)')),
            DropdownMenuItem(value: 'USD', child: Text('Dólar (USD)')),
            DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
          ],
          onChanged: canEditFinancial ? (v) async {
            if (v == null || v == _currencyCode) return;
            setState(() { _currencyCode = v; });
            // Reprecificar itens para a moeda selecionada
            await _repriceCatalogItemsForCurrency(v);
            if (!_projectValueOverridden && _catalogItems.isNotEmpty) {
              setState(() { _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ','); });
            }
          } : null,
          decoration: const InputDecoration(labelText: 'Moeda'),
        ),
      ),
      const SizedBox(width: 12),
      // Valor do projeto
      SizedBox(
        width: 200,
        child: GenericNumberField(
          controller: _valueText,
          enabled: canEditFinancial,
          allowDecimals: true,
          labelText: 'Valor do projeto',
          prefixText: '${_currencySymbol(_currencyCode)} ',
          onChanged: (_) { setState(() { _projectValueOverridden = true; }); },
        ),
      ),
      const Spacer(),
      TextOnlyButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        label: 'Cancelar',
      ),
      PrimaryButton(
        onPressed: _saving ? null : _save,
        label: 'Salvar',
        isLoading: _saving,
      ),
    ];
  }
}

class _CostItem {
  final TextEditingController descController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  void dispose() { descController.dispose(); valueController.dispose(); }
}

class _CatalogItem {
  final String uniqueId; // ID único para permitir duplicatas
  final String itemType; // product | package
  final String itemId;
  final String name;
  final String currency;
  final int priceCents;
  final String? thumbUrl;
  final String? comment; // Comentário específico deste projeto

  _CatalogItem({
    String? uniqueId,
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.currency,
    required this.priceCents,
    this.thumbUrl,
    this.comment,
  }) : uniqueId = uniqueId ?? '${DateTime.now().millisecondsSinceEpoch}_${itemType}_$itemId';

  _CatalogItem copyWith({
    String? uniqueId,
    String? itemType,
    String? itemId,
    String? name,
    String? currency,
    int? priceCents,
    String? thumbUrl,
    String? comment,
  }) => _CatalogItem(
    uniqueId: uniqueId ?? this.uniqueId,
    itemType: itemType ?? this.itemType,
    itemId: itemId ?? this.itemId,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    priceCents: priceCents ?? this.priceCents,
    thumbUrl: thumbUrl ?? this.thumbUrl,
    comment: comment ?? this.comment,
  );
}


class _SelectCatalogItemDialog extends StatefulWidget {
  final String currency;
  const _SelectCatalogItemDialog({required this.currency});
  @override
  State<_SelectCatalogItemDialog> createState() => _SelectCatalogItemDialogState();
}

class _SelectCatalogItemDialogState extends State<_SelectCatalogItemDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final prods = await client.from('products').select('id, name, currency_code, price_cents, price_map, image_url, image_thumb_url, image_drive_file_id').order('name');
      final packs = await client.from('packages').select('id, name, currency_code, price_cents, price_map, image_url, image_thumb_url, image_drive_file_id').order('name');
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(prods as List? ?? []);
        _packages = List<Map<String, dynamic>>.from(packs as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return; setState(() { _error = 'Falha ao carregar catálogo'; _loading = false; });
    }
  }

  String _fmt(int cents) => (cents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
  String _sym(String? code) { if (code == 'USD') return '\$'; if (code == 'EUR') return '€'; return 'R\$'; }

  Widget _leadingThumb(Map<String, dynamic> p) {
    final url = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
    if (url == null || url.isEmpty) {
      return const CircleAvatar(radius: 18, child: Icon(Icons.image_not_supported, size: 18));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(url, width: 48, height: 48, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: 'Selecionar Item do Catálogo',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      isLoading: _loading,
      actions: [
        TextOnlyButton(onPressed: () => Navigator.pop(context), label: 'Cancelar'),
      ],
      child: _loading
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Erro: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                GenericTabView(
                  height: 400,
                  tabs: const [
                    TabConfig(text: 'Produtos'),
                    TabConfig(text: 'Pacotes'),
                  ],
                  children: [
                      ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _products[i];
                          return ListTile(
                            leading: _leadingThumb(p),
                            title: Text(p['name'] ?? ''),
                            subtitle: Builder(builder: (_) {
                              final pm = (p['price_map'] as Map?)?.cast<String, dynamic>();
                              final cents = pm != null && pm[widget.currency] is int
                                  ? pm[widget.currency] as int
                                  : ((p['currency_code'] == widget.currency) ? (p['price_cents'] as int? ?? 0) : 0);
                              return Text('${_sym(widget.currency)} ${_fmt(cents)}');
                            }),
                            onTap: () {
                              final pm = (p['price_map'] as Map?)?.cast<String, dynamic>();
                              final cents = pm != null && pm[widget.currency] is int
                                  ? pm[widget.currency] as int
                                  : ((p['currency_code'] == widget.currency) ? (p['price_cents'] as int? ?? 0) : 0);
                              Navigator.pop(context, _CatalogItem(
                                itemType: 'product',
                                itemId: p['id'] as String,
                                name: p['name'] as String? ?? '-',
                                currency: widget.currency,
                                priceCents: cents,
                                thumbUrl: (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?),
                              ));
                            },
                          );
                        },
                      ),
                      ListView.separated(
                        itemCount: _packages.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _packages[i];
                          return ListTile(
                            leading: _leadingThumb(p),
                            title: Text(p['name'] ?? ''),
                            subtitle: Builder(builder: (_) {
                              final pm = (p['price_map'] as Map?)?.cast<String, dynamic>();
                              final cents = pm != null && pm[widget.currency] is int
                                  ? pm[widget.currency] as int
                                  : ((p['currency_code'] == widget.currency) ? (p['price_cents'] as int? ?? 0) : 0);
                              return Text('${_sym(widget.currency)} ${_fmt(cents)}');
                            }),
                            onTap: () {
                              final pm = (p['price_map'] as Map?)?.cast<String, dynamic>();
                              final cents = pm != null && pm[widget.currency] is int
                                  ? pm[widget.currency] as int
                                  : ((p['currency_code'] == widget.currency) ? (p['price_cents'] as int? ?? 0) : 0);
                              Navigator.pop(context, _CatalogItem(
                                itemType: 'package',
                                itemId: p['id'] as String,
                                name: p['name'] as String? ?? '-',
                                currency: widget.currency,
                                priceCents: cents,
                                thumbUrl: (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?),
                              ));
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
    );
  }
}

