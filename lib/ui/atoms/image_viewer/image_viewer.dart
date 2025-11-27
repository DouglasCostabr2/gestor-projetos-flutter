import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import '../buttons/buttons.dart';

/// Widget para visualização de imagens com zoom e pan (arrastar).
///
/// Funcionalidades:
/// - Zoom in/out com gestos de pinça ou scroll do mouse
/// - Arrastar para mover a imagem
/// - Duplo toque para zoom
/// - Botões de controle de zoom
/// - Botão de fechar
/// - Botão de download
/// - Suporte para imagens de rede (HTTP) e locais (File)
class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;
  final String? downloadFileName;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.downloadFileName,
  });

  /// Abre o visualizador de imagens em tela cheia
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
    String? downloadFileName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
          downloadFileName: downloadFileName,
        ),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PhotoViewController _photoViewController;

  @override
  void initState() {
    super.initState();
    _photoViewController = PhotoViewController();
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentScale = _photoViewController.scale ?? 1.0;
    _photoViewController.scale = (currentScale * 1.5).clamp(0.5, 4.0);
  }

  void _zoomOut() {
    final currentScale = _photoViewController.scale ?? 1.0;
    _photoViewController.scale = (currentScale / 1.5).clamp(0.5, 4.0);
  }

  void _resetZoom() {
    _photoViewController.scale = 1.0;
    _photoViewController.position = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final isAsset = widget.imageUrl.startsWith('assets/');
    final isHttp = widget.imageUrl.startsWith('http://') ||
        widget.imageUrl.startsWith('https://');
    final isFile = widget.imageUrl.startsWith('file://') ||
        (!isHttp &&
            !isAsset &&
            (widget.imageUrl.contains('\\\\') ||
                widget.imageUrl.contains('/')));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Visualizador de imagem com zoom e pan
          Center(
            child: widget.heroTag != null
                ? Hero(
                    tag: widget.heroTag!,
                    child: _buildPhotoView(isHttp, isFile, isAsset),
                  )
                : _buildPhotoView(isHttp, isFile, isAsset),
          ),
          // Botões de ação no topo (download e fechar)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão de download
                    IconOnlyButton(
                      onPressed: () => _downloadImage(context),
                      icon: Icons.download_rounded,
                      tooltip: 'Baixar imagem',
                      iconSize: 24,
                      iconColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      variant: IconButtonVariant.filled,
                      padding: const EdgeInsets.all(12),
                    ),
                    const SizedBox(width: 8),
                    // Botão de fechar
                    IconOnlyButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close,
                      tooltip: 'Fechar',
                      iconSize: 24,
                      iconColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      variant: IconButtonVariant.filled,
                      padding: const EdgeInsets.all(12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Controles de zoom na lateral direita
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom in
                    IconOnlyButton(
                      onPressed: _zoomIn,
                      icon: Icons.add,
                      tooltip: 'Aumentar zoom',
                      iconSize: 24,
                      iconColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      variant: IconButtonVariant.filled,
                      padding: const EdgeInsets.all(12),
                    ),
                    const SizedBox(height: 8),
                    // Reset zoom
                    IconOnlyButton(
                      onPressed: _resetZoom,
                      icon: Icons.fit_screen,
                      tooltip: 'Resetar zoom',
                      iconSize: 24,
                      iconColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      variant: IconButtonVariant.filled,
                      padding: const EdgeInsets.all(12),
                    ),
                    const SizedBox(height: 8),
                    // Zoom out
                    IconOnlyButton(
                      onPressed: _zoomOut,
                      icon: Icons.remove,
                      tooltip: 'Diminuir zoom',
                      iconSize: 24,
                      iconColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      variant: IconButtonVariant.filled,
                      padding: const EdgeInsets.all(12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final isHttp = widget.imageUrl.startsWith('http://') ||
          widget.imageUrl.startsWith('https://');
      final isFile = widget.imageUrl.startsWith('file://') ||
          (!isHttp &&
              (widget.imageUrl.contains('\\') ||
                  widget.imageUrl.contains('/')));

      // Sugerir nome com extensão adequada
      String suggestedName = widget.downloadFileName ??
          'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (widget.downloadFileName == null) {
        if (isHttp) {
          final uri = Uri.tryParse(widget.imageUrl);
          final last = (uri?.pathSegments.isNotEmpty ?? false)
              ? uri!.pathSegments.last
              : '';
          if (last.isNotEmpty && last.contains('.')) {
            final ext = last.split('.').last;
            suggestedName =
                'image_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
          }
        } else if (isFile) {
          final srcPath = widget.imageUrl.startsWith('file://')
              ? widget.imageUrl.substring(7)
              : widget.imageUrl;
          final base = srcPath.split(RegExp(r'[\\/]')).last;
          final ext = base.contains('.') ? base.split('.').last : 'jpg';
          suggestedName = 'image_${DateTime.now().millisecondsSinceEpoch}.$ext';
        }
      }

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar imagem',
        fileName: suggestedName,
        type: FileType.any,
      );
      if (outputPath == null) return;

      // Mostrar indicador de progresso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Baixando imagem...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      if (isFile) {
        final srcPath = widget.imageUrl.startsWith('file://')
            ? widget.imageUrl.substring(7)
            : widget.imageUrl;
        await File(srcPath).copy(outputPath);
      } else {
        final response = await http.get(Uri.parse(widget.imageUrl));
        if (response.statusCode == 200) {
          await File(outputPath).writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Erro ao baixar imagem: ${response.statusCode}');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Imagem baixada com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao baixar imagem: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Widget _buildPhotoView(bool isHttp, bool isFile, bool isAsset) {
    if (isAsset) {
      return PhotoView(
        controller: _photoViewController,
        imageProvider: AssetImage(widget.imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        initialScale: PhotoViewComputedScale.contained,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        filterQuality: FilterQuality.high,
        enableRotation: false,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Erro ao carregar imagem',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    if (isHttp) {
      return PhotoView(
        controller: _photoViewController,
        imageProvider: CachedNetworkImageProvider(widget.imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered *
            4, // Permite zoom maior para ver detalhes
        initialScale: PhotoViewComputedScale.contained,
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        // Habilita filtro de qualidade máxima
        filterQuality: FilterQuality.high,
        // Desabilita o gesto de escala base para permitir zoom ilimitado nos detalhes
        enableRotation: false,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? null
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
            color: Colors.white,
          ),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Erro ao carregar imagem',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Imagem local
    final localPath = widget.imageUrl.startsWith('file://')
        ? widget.imageUrl.substring(7)
        : widget.imageUrl;
    return PhotoView(
      controller: _photoViewController,
      imageProvider: FileImage(File(localPath)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered *
          4, // Permite zoom maior para ver detalhes
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      // Habilita filtro de qualidade máxima
      filterQuality: FilterQuality.high,
      // Desabilita o gesto de escala base para permitir zoom ilimitado nos detalhes
      enableRotation: false,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar imagem',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
