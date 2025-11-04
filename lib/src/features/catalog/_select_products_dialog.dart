import 'package:flutter/material.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

class SelectProductsDialog extends StatefulWidget {
  const SelectProductsDialog({
    super.key,
    required this.products,
    required this.alreadySelected,
  });

  final List<Map<String, dynamic>> products;
  final Set<String> alreadySelected;

  @override
  State<SelectProductsDialog> createState() => SelectProductsDialogState();
}

class SelectProductsDialogState extends State<SelectProductsDialog> {
  String _query = '';
  String? _categoryFilter; // null = todas
  String _sort = 'name_asc';
  final Map<String, int> _pending = {}; // product_id -> qty

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    var list = widget.products.where((p) {
      if (widget.alreadySelected.contains((p['id'] ?? '').toString())) return false;
      // filtro por busca
      if (q.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        if (!name.contains(q)) return false;
      }
      // filtro por categoria (usa texto de 'category' quando disponível)
      if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
        final cat = (p['category'] ?? '').toString();
        if (cat != _categoryFilter) return false;
      }
      return true;
    }).toList();
    // ordenação alfabética
    list.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return _sort == 'name_desc' ? bn.compareTo(an) : an.compareTo(bn);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: 'Adicionar produtos',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final res = <Map<String, dynamic>>[];
            _pending.forEach((id, qty) {
              if (qty > 0) res.add({'product_id': id, 'quantity': qty});
            });
            Navigator.pop(context, res);
          },
          child: const Text('Adicionar selecionados'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            // Busca + filtro + ordenação
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar produto',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _categoryFilter ?? 'ALL',
                onChanged: (v) => setState(() => _categoryFilter = (v == null || v == 'ALL') ? null : v),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Todas')),
                  ...{
                    for (final p in widget.products)
                      (p['category'] ?? '').toString()
                  }
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                ],
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? 'name_asc'),
                items: const [
                  DropdownMenuItem(value: 'name_asc', child: Text('Nome A→Z')),
                  DropdownMenuItem(value: 'name_desc', child: Text('Nome Z→A')),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _filtered.isEmpty
                  ? const Center(child: Text('Nenhum produto'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        final id = (p['id'] ?? '').toString();
                        final name = (p['name'] ?? '-') as String;
                        final qty = _pending[id] ?? 0;
                        return ListTile(
                          title: Text(name),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconOnlyButton(
                              icon: Icons.remove_circle_outline,
                              tooltip: 'Diminuir quantidade',
                              onPressed: qty > 0 ? () => setState(() => _pending[id] = qty - 1) : null,
                            ),
                            SizedBox(width: 44, child: Center(child: Text('$qty'))),
                            IconOnlyButton(
                              icon: Icons.add_circle_outline,
                              tooltip: 'Aumentar quantidade',
                              onPressed: () => setState(() => _pending[id] = qty + 1),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

