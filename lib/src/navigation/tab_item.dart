import 'package:flutter/material.dart';

/// Representa uma aba no sistema de abas
class TabItem {
  final String id;
  final String title;
  final IconData icon;
  final Widget page;
  final bool canClose;
  final int selectedMenuIndex; // Índice do item selecionado no side menu para esta aba

  TabItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.page,
    this.canClose = true,
    this.selectedMenuIndex = 0, // Por padrão, Home (índice 0)
  });

  TabItem copyWith({
    String? id,
    String? title,
    IconData? icon,
    Widget? page,
    bool? canClose,
    int? selectedMenuIndex,
  }) {
    return TabItem(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      page: page ?? this.page,
      canClose: canClose ?? this.canClose,
      selectedMenuIndex: selectedMenuIndex ?? this.selectedMenuIndex,
    );
  }
}

