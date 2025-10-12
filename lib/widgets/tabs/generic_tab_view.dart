import 'package:flutter/material.dart';

/// Configuração de uma tab individual
class TabConfig {
  final String text;
  final IconData? icon;

  const TabConfig({
    required this.text,
    this.icon,
  });

  Tab toTab() {
    if (icon != null) {
      return Tab(icon: Icon(icon), text: text);
    }
    return Tab(text: text);
  }
}

/// Widget genérico reutilizável para criar sistemas de tabs
/// 
/// Exemplo de uso:
/// ```dart
/// GenericTabView(
///   tabs: [
///     TabConfig(text: 'Tab 1', icon: Icons.home),
///     TabConfig(text: 'Tab 2'),
///   ],
///   children: [
///     Widget1(),
///     Widget2(),
///   ],
/// )
/// ```
class GenericTabView extends StatefulWidget {
  /// Lista de configurações das tabs
  final List<TabConfig> tabs;
  
  /// Lista de widgets que serão exibidos em cada tab
  final List<Widget> children;
  
  /// Altura fixa para o TabBarView (opcional)
  /// Se null, o TabBarView irá expandir para preencher o espaço disponível
  final double? height;
  
  /// Callback chamado quando a tab é alterada
  final void Function(int index)? onTabChanged;
  
  /// Índice inicial da tab selecionada
  final int initialIndex;
  
  /// Se true, permite swipe entre tabs
  final bool enableSwipe;

  const GenericTabView({
    super.key,
    required this.tabs,
    required this.children,
    this.height,
    this.onTabChanged,
    this.initialIndex = 0,
    this.enableSwipe = true,
  }) : assert(tabs.length == children.length, 'tabs e children devem ter o mesmo tamanho');

  @override
  State<GenericTabView> createState() => _GenericTabViewState();
}

class _GenericTabViewState extends State<GenericTabView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    
    // Adiciona listener para notificar mudanças de tab
    if (widget.onTabChanged != null) {
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          widget.onTabChanged!(_tabController.index);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      tabs: widget.tabs.map((config) => config.toTab()).toList(),
    );

    final tabBarView = TabBarView(
      controller: _tabController,
      physics: widget.enableSwipe 
          ? const AlwaysScrollableScrollPhysics() 
          : const NeverScrollableScrollPhysics(),
      children: widget.children,
    );

    // Se altura fixa foi especificada
    if (widget.height != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          const Divider(height: 1),
          SizedBox(
            height: widget.height,
            child: tabBarView,
          ),
        ],
      );
    }

    // Se deve expandir para preencher o espaço disponível
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabBar,
        const Divider(height: 1),
        Expanded(child: tabBarView),
      ],
    );
  }
}

