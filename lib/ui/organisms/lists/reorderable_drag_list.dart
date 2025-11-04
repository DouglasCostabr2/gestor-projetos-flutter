import 'package:flutter/material.dart';

/// Widget reutilizável para listas com drag and drop (reordenação)
///
/// Este componente fornece uma interface consistente para listas reordenáveis
/// com drag handles personalizáveis e callbacks de reordenação.
///
/// Características:
/// - Drag handle customizável (ícone, cor, tamanho)
/// - Suporte para listas de qualquer tipo genérico
/// - Callbacks para reordenação
/// - Opção de habilitar/desabilitar drag
/// - Suporte para keys únicas por item
/// - Integração com ScrollView
///
/// Exemplo de uso:
/// ```dart
/// ReorderableDragList<CatalogItem>(
///   items: _catalogItems,
///   enabled: true,
///   onReorder: (oldIndex, newIndex) {
///     setState(() {
///       if (newIndex > oldIndex) newIndex -= 1;
///       final item = _catalogItems.removeAt(oldIndex);
///       _catalogItems.insert(newIndex, item);
///     });
///   },
///   itemBuilder: (context, item, index) {
///     return Container(
///       padding: EdgeInsets.all(8),
///       child: Text(item.name),
///     );
///   },
///   getKey: (item) => item.id,
/// )
/// ```
class ReorderableDragList<T> extends StatelessWidget {
  /// Lista de itens a serem exibidos
  final List<T> items;

  /// Se o drag and drop está habilitado
  final bool enabled;

  /// Callback chamado quando um item é reordenado
  /// Recebe o índice antigo e o novo índice
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Builder para construir cada item da lista
  /// Recebe o contexto, o item e o índice
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Função para obter uma key única para cada item
  /// Usado para manter o estado dos widgets durante a reordenação
  final String Function(T item) getKey;

  /// Ícone do drag handle (padrão: Icons.drag_indicator)
  final IconData dragHandleIcon;

  /// Tamanho do ícone do drag handle (padrão: 24)
  final double dragHandleSize;

  /// Cor do ícone do drag handle (padrão: cinza com opacidade)
  final Color? dragHandleColor;

  /// Padding ao redor do drag handle (padrão: EdgeInsets.only(right: 8))
  final EdgeInsets dragHandlePadding;

  /// Permite definir padding do handle por item
  final EdgeInsets Function(int index, T item)? dragHandlePaddingBuilder;

  /// Define se um item específico irá renderizar o próprio handle internamente.
  /// Quando retornar true, o handle padrão à esquerda NÃO será exibido para aquele item.
  final bool Function(int index, T item)? useInternalHandle;

  /// Se deve usar shrinkWrap (padrão: true)
  final bool shrinkWrap;

  /// Physics do scroll (padrão: NeverScrollableScrollPhysics)
  final ScrollPhysics? physics;

  /// Padding da lista (padrão: EdgeInsets.zero)
  final EdgeInsets padding;

  /// Widget a ser exibido quando a lista está vazia
  final Widget? emptyWidget;

  const ReorderableDragList({
    super.key,
    required this.items,
    required this.onReorder,
    required this.itemBuilder,
    required this.getKey,
    this.enabled = true,
    this.dragHandleIcon = Icons.drag_indicator,
    this.dragHandleSize = 24,
    this.dragHandleColor,
    this.dragHandlePadding = const EdgeInsets.only(right: 8),
    this.dragHandlePaddingBuilder,
    this.useInternalHandle,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) return emptyWidget!;
    if (items.isEmpty) return const SizedBox.shrink();

    return ReorderableListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: enabled ? onReorder : (oldIndex, newIndex) {},
      itemBuilder: (context, index) {
        final item = items[index];
        final key = getKey(item);
        final showExternalHandle = !(useInternalHandle?.call(index, item) ?? false);
        final perItemPadding = dragHandlePaddingBuilder?.call(index, item) ?? dragHandlePadding;

        return _DragListItem<T>(
          key: ValueKey(key),
          item: item,
          index: index,
          enabled: enabled,
          dragHandleIcon: dragHandleIcon,
          dragHandleSize: dragHandleSize,
          dragHandleColor: dragHandleColor ?? const Color(0xFF9AA0A6).withValues(alpha: 0.5),
          dragHandlePadding: perItemPadding,
          itemBuilder: itemBuilder,
          showExternalHandle: showExternalHandle,
        );
      },
    );
  }
}

/// Widget interno que representa um item da lista com drag handle
class _DragListItem<T> extends StatelessWidget {
  final T item;
  final int index;
  final bool enabled;
  final IconData dragHandleIcon;
  final double dragHandleSize;
  final Color dragHandleColor;
  final EdgeInsets dragHandlePadding;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool showExternalHandle;

  const _DragListItem({
    super.key,
    required this.item,
    required this.index,
    required this.enabled,
    required this.dragHandleIcon,
    required this.dragHandleSize,
    required this.dragHandleColor,
    required this.dragHandlePadding,
    required this.itemBuilder,
    required this.showExternalHandle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle externo (apenas se habilitado e solicitado)
        if (enabled && showExternalHandle)
          Padding(
            padding: dragHandlePadding,
            child: ReorderableDragStartListener(
              index: index,
              child: Icon(
                dragHandleIcon,
                size: dragHandleSize,
                color: dragHandleColor,
              ),
            ),
          ),

        // Conteúdo do item
        Expanded(
          child: itemBuilder(context, item, index),
        ),
      ],
    );
  }
}

/// Variante simplificada sem drag handle visível
/// Útil quando você quer que o item inteiro seja arrastável
class ReorderableDragListFullItem<T> extends StatelessWidget {
  /// Lista de itens a serem exibidos
  final List<T> items;

  /// Se o drag and drop está habilitado
  final bool enabled;

  /// Callback chamado quando um item é reordenado
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Builder para construir cada item da lista
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Função para obter uma key única para cada item
  final String Function(T item) getKey;

  /// Se deve usar shrinkWrap (padrão: true)
  final bool shrinkWrap;

  /// Physics do scroll (padrão: NeverScrollableScrollPhysics)
  final ScrollPhysics? physics;

  /// Padding da lista (padrão: EdgeInsets.zero)
  final EdgeInsets padding;

  /// Widget a ser exibido quando a lista está vazia
  final Widget? emptyWidget;

  const ReorderableDragListFullItem({
    super.key,
    required this.items,
    required this.onReorder,
    required this.itemBuilder,
    required this.getKey,
    this.enabled = true,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      buildDefaultDragHandles: enabled, // Usa handles padrão do Flutter
      itemCount: items.length,
      onReorder: enabled ? onReorder : (oldIndex, newIndex) {},
      itemBuilder: (context, index) {
        final item = items[index];
        final key = getKey(item);

        return Container(
          key: ValueKey(key),
          child: itemBuilder(context, item, index),
        );
      },
    );
  }
}

