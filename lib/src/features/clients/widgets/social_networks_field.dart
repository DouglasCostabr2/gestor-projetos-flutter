import 'package:flutter/material.dart';
import 'package:my_business/ui/molecules/containers/section_container.dart';
import 'package:my_business/ui/molecules/containers/dashed_container.dart';
import 'package:my_business/ui/atoms/inputs/generic_text_field.dart';
import 'package:my_business/ui/atoms/buttons/icon_only_button.dart';
import 'package:my_business/ui/theme/ui_constants.dart';

/// Widget para gerenciar redes sociais de um cliente
/// Similar ao componente de "Adicionar Produto" do formulário de projeto
class SocialNetworksField extends StatefulWidget {
  final List<SocialNetwork> initialNetworks;
  final ValueChanged<List<SocialNetwork>> onChanged;
  final bool enabled;

  const SocialNetworksField({
    super.key,
    required this.initialNetworks,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<SocialNetworksField> createState() => _SocialNetworksFieldState();
}

class _SocialNetworksFieldState extends State<SocialNetworksField> {
  late List<SocialNetwork> _networks;

  @override
  void initState() {
    super.initState();
    _networks = List.from(widget.initialNetworks);
  }

  void _addNetwork() {
    setState(() {
      _networks.add(SocialNetwork(name: '', url: ''));
      widget.onChanged(_networks);
    });
  }

  void _removeNetwork(int index) {
    setState(() {
      _networks[index].dispose();
      _networks.removeAt(index);
      widget.onChanged(_networks);
    });
  }

  void _updateNetwork(int index, String name, String url) {
    _networks[index].name = name;
    _networks[index].url = url;
    widget.onChanged(_networks);
  }

  @override
  void dispose() {
    for (final network in _networks) {
      network.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Botão "Adicionar Rede Social" com borda tracejada
          _DashedActionBox(
            enabled: widget.enabled,
            onTap: widget.enabled ? _addNetwork : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Text(
                  'Adicionar rede social',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Lista de redes sociais adicionadas
          if (_networks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(_networks.length, (index) {
              final network = _networks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Campo: Nome da rede social
                    Expanded(
                      flex: 1,
                      child: GenericTextField(
                        controller: network.nameController,
                        labelText: 'Rede Social',
                        hintText: 'Instagram, Facebook, LinkedIn...',
                        enabled: widget.enabled,
                        onChanged: (value) => _updateNetwork(index, value, network.url),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Campo: URL ou usuário
                    Expanded(
                      flex: 2,
                      child: GenericTextField(
                        controller: network.urlController,
                        labelText: 'Link ou @usuário',
                        hintText: 'https://instagram.com/usuario ou @usuario',
                        enabled: widget.enabled,
                        onChanged: (value) => _updateNetwork(index, network.name, value),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botão remover
                    if (widget.enabled)
                      IconOnlyButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Remover',
                        onPressed: () => _removeNetwork(index),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Modelo de dados para uma rede social
class SocialNetwork {
  String name;
  String url;
  final TextEditingController nameController;
  final TextEditingController urlController;

  SocialNetwork({
    required this.name,
    required this.url,
  })  : nameController = TextEditingController(text: name),
        urlController = TextEditingController(text: url);

  /// Converte para Map para salvar no banco
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'url': url.trim(),
  };

  /// Cria a partir de um Map do banco
  factory SocialNetwork.fromJson(Map<String, dynamic> json) {
    return SocialNetwork(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  void dispose() {
    nameController.dispose();
    urlController.dispose();
  }
}

/// Componente de botão com borda tracejada e hover effect
/// Usado para ações de adicionar (redes sociais, etc.)
class _DashedActionBox extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;

  const _DashedActionBox({
    required this.onTap,
    required this.child,
    this.enabled = true,
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

    if (!widget.enabled) return Opacity(opacity: 0.5, child: box);

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

