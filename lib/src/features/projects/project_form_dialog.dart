import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/src/utils/money.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/ui/organisms/lists/lists.dart';
import 'package:my_business/ui/organisms/tabs/tabs.dart';
import 'package:my_business/modules/projects/module.dart';
import 'package:my_business/modules/common/organization_context.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';
import 'package:my_business/ui/molecules/containers/dashed_container.dart';
import 'package:my_business/ui/molecules/containers/section_container.dart';
import 'package:my_business/ui/atoms/inputs/inputs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/theme/ui_constants.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_field.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_area.dart';
import 'package:my_business/services/mentions_service.dart';

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
  final _description = TextEditingController(); // Controller para descrição com menções
  String _descriptionText = ''; // Texto da descrição (plain text)
  String _descriptionJson = ''; // JSON da descrição (rich text - AppFlowy Editor)
  final _valueText = TextEditingController();
  String _currencyCode = 'BRL'; // BRL | USD | EUR

  // Descontos (lista de descontos)
  final List<_DiscountItem> _discounts = [];
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
      _description.text = _descriptionText; // Inicializar controller com texto da descrição
      // Não carregar value_cents aqui, pois será calculado automaticamente
      // a partir dos produtos e custos adicionais
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
        await _loadDiscounts(i['id'] as String);
        await _loadCatalogItems(i['id'] as String);
        if (!mounted) return;
        setState(() {
          // Atualizar o valor do projeto com o total calculado
          _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
        });
      });
    }
  }

  Future<void> _loadAdditionalCosts(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_additional_costs')
          .select('description, amount_cents, type')
          .eq('project_id', projectId);
      setState(() {
        _costs.clear();
        for (final r in rows as List<dynamic>) {
          final m = r as Map<String, dynamic>;
          final item = _CostItem();
          item.descController.text = (m['description'] as String?) ?? '';
          final cents = (m['amount_cents'] as int?) ?? 0;
          item.valueController.text = _formatCents(cents).replaceAll('.', ',');
          item.type = (m['type'] as String?) ?? 'fixed'; // Carregar tipo
          _costs.add(item);
        }
      });
    } catch (e) {
      // Silently fail - costs are optional
    }
  }

  Future<void> _loadDiscounts(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_discounts')
          .select('description, value_cents, type')
          .eq('project_id', projectId);
      setState(() {
        _discounts.clear();
        for (final r in rows as List<dynamic>) {
          final m = r as Map<String, dynamic>;
          final item = _DiscountItem();
          item.descController.text = (m['description'] as String?) ?? '';
          final cents = (m['value_cents'] as int?) ?? 0;
          item.valueController.text = _formatCents(cents).replaceAll('.', ',');
          item.type = (m['type'] as String?) ?? 'percentage'; // Carregar tipo
          _discounts.add(item);
        }
      });
    } catch (e) {
      // Silently fail - discounts are optional
    }
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
        // Ignorar erro (operação não crítica)
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
        // Ignorar erro (operação não crítica)
      }

      setState(() {
        _catalogItems.clear();
        for (final m in list) {
          final kind = (m['kind'] as String?) ?? 'product';
          final id = (m['item_id'] ?? '').toString();
          final key = '$kind:$id';
          final thumb = thumbByKey[key];
          final priceCents = (m['unit_price_cents'] as int?) ?? 0;
          _catalogItems.add(_CatalogItem(
            itemType: kind,
            itemId: id,
            name: (m['name'] as String?) ?? '-',
            currency: (m['currency_code'] as String?) ?? _currencyCode,
            priceCents: priceCents,
            thumbUrl: thumb,
            comment: (m['comment'] as String?),
          ));
        }
      });
    } catch (e) {
      // Silently fail - catalog items are optional
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _valueText.dispose();
    for (final c in _costs) { c.dispose(); }
    for (final item in _catalogItems) { item.dispose(); }
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
        // Ignorar erro (operação não crítica)
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
      // Ignorar erro (operação não crítica)
    }
  }

  int get _catalogSumCents => _catalogItems.where((it) => it.currency == _currencyCode).fold<int>(0, (sum, it) => sum + it.priceCents);

  int get _additionalCostsSumCents {
    // Calcular custos progressivamente: cada porcentagem é calculada sobre o subtotal acumulado
    int runningTotal = _catalogSumCents;
    for (final c in _costs) {
      final costValue = _parseMoneyToCents(c.valueController.text);
      if (c.type == 'percentage') {
        // Porcentagem sobre o subtotal acumulado até agora
        runningTotal += (runningTotal * costValue / 10000).round();
      } else {
        // Valor fixo
        runningTotal += costValue;
      }
    }
    return runningTotal - _catalogSumCents; // Retornar apenas a soma dos custos
  }

  int get _discountCents {
    final subtotal = _catalogSumCents + _additionalCostsSumCents;
    // Calcular descontos progressivamente
    int totalDiscount = 0;
    int remainingSubtotal = subtotal;
    for (final d in _discounts) {
      final discountValue = _parseMoneyToCents(d.valueController.text);
      int thisDiscount = 0;
      if (d.type == 'percentage') {
        // Porcentagem sobre o subtotal restante
        thisDiscount = (remainingSubtotal * discountValue / 10000).round();
      } else {
        // Valor fixo
        thisDiscount = discountValue;
      }
      totalDiscount += thisDiscount;
      remainingSubtotal -= thisDiscount;
    }
    return totalDiscount;
  }

  int get _autoTotalCents {
    final subtotal = _catalogSumCents + _additionalCostsSumCents;
    final discount = _discountCents;
    final total = subtotal - discount;
    return total > 0 ? total : 0; // Não permitir valores negativos
  }

  // Verificar se o desconto excede o subtotal
  bool get _hasExcessiveDiscount {
    final subtotal = _catalogSumCents + _additionalCostsSumCents;
    final discount = _discountCents;
    return discount > subtotal;
  }



  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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
        'value_cents': _autoTotalCents, // Sempre salvar o total calculado
      };
      String? projectId;
      if (widget.initial == null) {
        // Obter organization_id
        final orgId = OrganizationContext.currentOrganizationId;
        if (orgId == null) throw Exception('Nenhuma organização ativa');

        final payload = {
          ...base,
          'client_id': widget.fixedClientId ?? _clientId,
          'company_id': _companyId,
          'owner_id': uid,
          'status': _status,
          'organization_id': orgId,
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
        // Usar o módulo para atualizar o projeto (isso vai renomerar a pasta no Google Drive se necessário)
        await projectsModule.updateProject(
          projectId: projectId,
          updates: payload,
        );
      }
      if (projectId.isNotEmpty) {
        // Salvar menções do título e descrição
        final mentionsService = MentionsService();
        try {
          await mentionsService.saveProjectMentions(
            projectId: projectId,
            fieldName: 'name',
            content: _name.text,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        try {
          await mentionsService.saveProjectMentions(
            projectId: projectId,
            fieldName: 'description',
            content: _description.text,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // Replace custos adicionais de forma isolada
        try {
          await client.from('project_additional_costs').delete().eq('project_id', projectId);
          if (_costs.isNotEmpty) {
            final rows = _costs.asMap().entries.map((entry) {
              final index = entry.key;
              final c = entry.value;
              // Se a descrição estiver vazia, usar descrição padrão
              final description = c.descController.text.trim().isEmpty
                  ? 'Custo adicional ${index + 1}'
                  : c.descController.text.trim();
              return {
                'project_id': projectId,
                'description': description,
                'amount_cents': _parseMoneyToCents(c.valueController.text),
                'currency_code': _currencyCode,
                'type': c.type,
                if (uid != null) 'created_by': uid,
              };
            }).toList();
            if (rows.isNotEmpty) {
              await client.from('project_additional_costs').insert(rows);
            }
          }
        } catch (e) {
          // Prosseguir mesmo que custos adicionais falhem
        }

        // Replace descontos de forma isolada
        try {
          await client.from('project_discounts').delete().eq('project_id', projectId);
          if (_discounts.isNotEmpty) {
            final rows = _discounts.asMap().entries.map((entry) {
              final index = entry.key;
              final d = entry.value;
              // Se a descrição estiver vazia, usar descrição padrão
              final description = d.descController.text.trim().isEmpty
                  ? 'Desconto ${index + 1}'
                  : d.descController.text.trim();
              return {
                'project_id': projectId,
                'description': description,
                'value_cents': _parseMoneyToCents(d.valueController.text),
                'type': d.type,
              };
            }).toList();
            if (rows.isNotEmpty) {
              await client.from('project_discounts').insert(rows);
            }
          }
        } catch (e) {
          // Prosseguir mesmo que descontos falhem
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
      customActionsLayout: true, // Usa layout customizado para o footer
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
                        onChanged: (v) async {
                          setState(() {
                            _clientId = v;
                            _companyId = null; // Limpa a empresa atual
                          });
                          // Carrega automaticamente a primeira empresa do cliente
                          if (v != null) {
                            try {
                              final companies = await Supabase.instance.client
                                  .from('companies')
                                  .select('id')
                                  .eq('client_id', v)
                                  .limit(1);
                              if (companies.isNotEmpty && mounted) {
                                setState(() {
                                  _companyId = companies.first['id'] as String?;
                                });
                              }
                            } catch (_) {
                              // Ignora erro ao carregar empresa
                            }
                          }
                        },
                        labelText: 'Cliente',
                        emptyMessage: 'Nenhum cliente cadastrado',
                        width: 300,
                      ),
                    if (widget.fixedClientId == null) const SizedBox(height: 12),
                    MentionTextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nome *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                      maxLines: 1,
                      onMentionsChanged: (userIds) {
                        // Menções serão salvas ao salvar o projeto
                      },
                    ),
                    const SizedBox(height: 12),
                    // Campo de descrição com suporte a menções
                    MentionTextArea(
                      controller: _description,
                      labelText: 'Descrição',
                      hintText: 'Descrição do projeto... (digite @ para mencionar)',
                      minLines: 3,
                      maxLines: 8,
                      enabled: !_saving,
                      onChanged: (text) {
                        setState(() {
                          _descriptionText = text;
                        });
                      },
                      onMentionsChanged: (userIds) {
                        // Menções serão salvas ao salvar o projeto
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
                    // Itens catálogo
                    SectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashedActionBox(
                            onTap: () async {
                              final selected = await showDialog<_CatalogItem>(
                                context: context,
                                builder: (_) => _SelectCatalogItemDialog(currency: _currencyCode),
                              );
                              if (selected != null) {
                                setState(() {
                                  _catalogItems.add(selected);
                                  // Sempre atualizar o valor do projeto
                                  _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                });
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Adicionar produto',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_catalogItems.isNotEmpty) ...[
                            const SizedBox(height: 12),
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
                                  key: ValueKey('price_${it.uniqueId}'),
                                  controller: it.priceController,
                                  enabled: canEditFinancial,
                                  allowDecimals: true,
                                  labelText: 'Preço',
                                  prefixText: '${_currencySymbol(it.currency)} ',
                                  onChanged: (v) {
                                    final cents = _parseMoneyToCents(v);
                                    // Atualiza apenas o valor em centavos, sem recriar o item
                                    it.updatePriceCents(cents);
                                    setState(() {
                                      // Sempre atualizar o valor do projeto
                                      _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
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
                                    setState(() { it.updateComment(text); });
                                  }
                                },
                              ),
                              IconOnlyButton(icon: Icons.delete_outline, tooltip: 'Remover', onPressed: () => setState(() {
                                _catalogItems.removeAt(index);
                                // Sempre atualizar o valor do projeto
                                _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Custos adicionais
                    Row(children: [
                      if (canEditFinancial)
                        IconTextButton(
                          onPressed: () {
                            setState(() {
                              _costs.add(_CostItem());
                              // Sempre atualizar o valor do projeto
                              _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                            });
                          },
                          icon: Icons.add,
                          label: 'Adicionar custo',
                        ),
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
                          // Tipo de custo (% ou símbolo da moeda)
                          SizedBox(
                            width: 120,
                            child: GenericDropdownField<String>(
                              value: c.type,
                              items: [
                                DropdownItem(value: 'percentage', label: '%'),
                                DropdownItem(value: 'fixed', label: _currencySymbol(_currencyCode)),
                              ],
                              onChanged: canEditFinancial ? (v) {
                                if (v == null) return;
                                setState(() {
                                  c.type = v;
                                  // Atualizar o valor do projeto
                                  _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                });
                              } : null,
                              labelText: 'Tipo',
                              enabled: canEditFinancial,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: GenericNumberField(
                            controller: c.valueController,
                            enabled: canEditFinancial,
                            allowDecimals: true,
                            labelText: 'Valor',
                            suffixText: c.type == 'percentage' ? '%' : null,
                            prefixText: c.type == 'fixed' ? '${_currencySymbol(_currencyCode)} ' : null,
                            onChanged: (_) {
                              setState(() {
                                // Sempre atualizar o valor do projeto
                                _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                              });
                            },
                          )),
                          const SizedBox(width: 8),
                          if (canEditFinancial)
                            IconOnlyButton(
                              onPressed: () {
                                setState(() {
                                  _costs.removeAt(i);
                                  // Sempre atualizar o valor do projeto
                                  _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                });
                              },
                              icon: Icons.delete_outline,
                              tooltip: 'Remover',
                            ),
                        ]),
                      );
                    }).toList()),
                    const SizedBox(height: 16),
                    // Descontos
                    Row(children: [
                      if (canEditFinancial)
                        IconTextButton(
                          onPressed: () {
                            setState(() {
                              _discounts.add(_DiscountItem());
                              // Sempre atualizar o valor do projeto
                              _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                            });
                          },
                          icon: Icons.add,
                          label: 'Adicionar desconto',
                        ),
                      const Spacer(),
                      Text('Descontos', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    Column(children: _discounts.asMap().entries.map((e) {
                      final i = e.key; final d = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(flex: 2, child: GenericTextField(controller: d.descController, enabled: canEditFinancial, labelText: 'Descrição')),
                          const SizedBox(width: 8),
                          // Tipo de desconto (% ou símbolo da moeda)
                          SizedBox(
                            width: 120,
                            child: GenericDropdownField<String>(
                              value: d.type,
                              items: [
                                DropdownItem(value: 'percentage', label: '%'),
                                DropdownItem(value: 'fixed', label: _currencySymbol(_currencyCode)),
                              ],
                              onChanged: canEditFinancial ? (v) {
                                if (v == null) return;
                                setState(() {
                                  d.type = v;
                                  // Atualizar o valor do projeto
                                  _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                });
                              } : null,
                              labelText: 'Tipo',
                              enabled: canEditFinancial,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: GenericNumberField(
                            controller: d.valueController,
                            enabled: canEditFinancial,
                            allowDecimals: true,
                            labelText: 'Valor',
                            suffixText: d.type == 'percentage' ? '%' : null,
                            prefixText: d.type == 'fixed' ? '${_currencySymbol(_currencyCode)} ' : null,
                            onChanged: (_) {
                              setState(() {
                                // Sempre atualizar o valor do projeto
                                _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                              });
                            },
                          )),
                          const SizedBox(width: 8),
                          if (canEditFinancial)
                            IconOnlyButton(
                              onPressed: () {
                                setState(() {
                                  _discounts.removeAt(i);
                                  // Sempre atualizar o valor do projeto
                                  _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ',');
                                });
                              },
                              icon: Icons.delete_outline,
                              tooltip: 'Remover',
                            ),
                        ]),
                      );
                    }).toList()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(bool canEditFinancial) {
    // Criar widget de totais
    final totalsWidget = _catalogItems.isNotEmpty && canEditFinancial
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2A2A2A)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Tooltip(
                    message: 'Total dos produtos do catálogo',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_currencySymbol(_currencyCode)} ${_formatCents(_catalogSumCents).replaceAll('.', ',')}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Tooltip(
                    message: 'Total dos custos adicionais',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_currencySymbol(_currencyCode)} ${_formatCents(_additionalCostsSumCents).replaceAll('.', ',')}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Tooltip(
                    message: 'Total geral (catálogo + custos adicionais)',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calculate_outlined, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_currencySymbol(_currencyCode)} ${_formatCents(_autoTotalCents).replaceAll('.', ',')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;

    // Criar linha de botões
    final buttonsRow = [
      // Moeda
      GenericDropdownField<String>(
        value: ['BRL','USD','EUR'].contains(_currencyCode) ? _currencyCode : 'BRL',
        items: const [
          DropdownItem(value: 'BRL', label: 'Real (BRL)'),
          DropdownItem(value: 'USD', label: 'Dólar (USD)'),
          DropdownItem(value: 'EUR', label: 'Euro (EUR)'),
        ],
        onChanged: canEditFinancial ? (v) async {
          if (v == null || v == _currencyCode) return;
          setState(() { _currencyCode = v; });
          // Reprecificar itens para a moeda selecionada
          await _repriceCatalogItemsForCurrency(v);
          // Sempre atualizar o valor do projeto
          setState(() { _valueText.text = _formatCents(_autoTotalCents).replaceAll('.', ','); });
        } : null,
        labelText: 'Moeda',
        enabled: canEditFinancial,
        width: 150,
        openUpwards: true, // Abre para cima pois está no footer
      ),
      const SizedBox(width: 12),
      // Valor do projeto
      SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GenericNumberField(
              controller: _valueText,
              enabled: true, // Habilitado para manter texto branco, mas será recalculado automaticamente
              allowDecimals: true,
              labelText: 'Valor do projeto',
              prefixText: '${_currencySymbol(_currencyCode)} ',
              onChanged: (_) {
                // Ignorar mudanças manuais - o valor será recalculado automaticamente
                // quando produtos/custos/desconto mudarem
              },
            ),
            if (_hasExcessiveDiscount)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Desconto excede o valor',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const Spacer(),
      TextOnlyButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        label: 'Cancelar',
      ),
      PrimaryButton(
        onPressed: _saving ? null : () {
          _save();
        },
        label: 'Salvar',
        isLoading: _saving,
      ),
    ];

    // Sempre retorna os botões, com ou sem totais
    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalsWidget != null) ...[
              totalsWidget,
              const SizedBox(height: 12),
            ],
            Row(children: buttonsRow),
          ],
        ),
      ),
    ];
  }
}

class _CostItem {
  final TextEditingController descController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  String type = 'percentage'; // 'percentage' ou 'fixed'
  void dispose() { descController.dispose(); valueController.dispose(); }
}

class _DiscountItem {
  final TextEditingController descController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  String type = 'percentage'; // 'percentage' ou 'fixed'
  void dispose() { descController.dispose(); valueController.dispose(); }
}

class _CatalogItem {
  final String uniqueId; // ID único para permitir duplicatas
  final String itemType; // product | package
  final String itemId;
  final String name;
  final String currency;
  int priceCents; // Mutável para permitir atualização sem recriar o objeto
  final String? thumbUrl;
  String? comment; // Comentário específico deste projeto (mutável)
  final TextEditingController priceController; // Controller para o campo de preço

  _CatalogItem({
    String? uniqueId,
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.currency,
    required this.priceCents,
    this.thumbUrl,
    this.comment,
  }) : uniqueId = uniqueId ?? '${DateTime.now().millisecondsSinceEpoch}_${itemType}_$itemId',
       priceController = TextEditingController(
         text: (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ','),
       );

  // Método para atualizar o preço sem recriar o objeto
  void updatePriceCents(int cents) {
    priceCents = cents;
  }

  // Método para atualizar o comentário sem recriar o objeto
  void updateComment(String? newComment) {
    comment = newComment;
  }

  _CatalogItem copyWith({
    String? uniqueId,
    String? itemType,
    String? itemId,
    String? name,
    String? currency,
    int? priceCents,
    String? thumbUrl,
    String? comment,
  }) {
    final newItem = _CatalogItem(
      uniqueId: uniqueId ?? this.uniqueId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      priceCents: priceCents ?? this.priceCents,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      comment: comment ?? this.comment,
    );
    // Se o preço mudou, atualiza o controller
    if (priceCents != null && priceCents != this.priceCents) {
      newItem.priceController.text = (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    } else {
      // Mantém o texto atual do controller (preserva o que o usuário está digitando)
      newItem.priceController.text = priceController.text;
    }
    return newItem;
  }

  void dispose() {
    priceController.dispose();
  }
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

      // Obter organization_id
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        throw Exception('Nenhuma organização ativa');
      }


      // Filtrar produtos e pacotes por organization_id
      final prods = await client
          .from('products')
          .select('id, name, currency_code, price_cents, price_map, image_url, image_thumb_url, image_drive_file_id')
          .eq('organization_id', orgId)
          .order('name');

      final packs = await client
          .from('packages')
          .select('id, name, currency_code, price_cents, price_map, image_url, image_thumb_url, image_drive_file_id')
          .eq('organization_id', orgId)
          .order('name');

      if (!mounted) return;


      setState(() {
        _products = List<Map<String, dynamic>>.from(prods);
        _packages = List<Map<String, dynamic>>.from(packs);
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

/// Componente de botão com borda tracejada e hover effect
/// Usado para ações de adicionar (produtos, custos, etc.)
class _DashedActionBox extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _DashedActionBox({
    required this.onTap,
    required this.child,
  });

  @override
  State<_DashedActionBox> createState() => _DashedActionBoxState();
}

class _DashedActionBoxState extends State<_DashedActionBox> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: _isHover ? 0.8 : 0.5);

    final overlay = _isHover
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;

    final box = DashedContainer(
      color: borderColor,
      strokeWidth: UIConst.dashedStroke,
      dashLength: UIConst.dashLengthDefault,
      dashGap: UIConst.dashGapDefault,
      borderRadius: UIConst.radiusSmall,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        color: overlay,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: widget.child,
      ),
    );

    return InkWell(
      onHover: (h) => setState(() => _isHover = h),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(UIConst.radiusSmall),
      onTap: widget.onTap,
      child: box,
    );
  }
}
