import 'dart:io';
import 'package:flutter/material.dart';
import '../../atoms/image_viewer/image_viewer.dart';

class AssetTile extends StatelessWidget {
  final Map<String, dynamic> fileData;
  final Function(Map<String, dynamic>) onDownload;
  final Function(Map<String, dynamic>)? onDelete;
  final bool isFromDesignMaterials;

  const AssetTile({
    super.key,
    required this.fileData,
    required this.onDownload,
    this.onDelete,
    this.isFromDesignMaterials = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = fileData;
    final driveFileId = f['drive_file_id'] as String?;
    final driveFileUrl = f['drive_file_url'] as String?;
    final mimeType = f['mime_type'] as String? ?? '';
    final filename = f['filename'] as String? ?? 'Sem nome';
    final isDesignMaterial =
        isFromDesignMaterials || f['is_from_design_materials'] == true;

    // Detecta se é local pela flag OU pela URL
    final isLocalFlag = f['is_local'] == true;
    final isLocalUrl =
        driveFileUrl != null && driveFileUrl.startsWith('file://');
    final isLocal = isLocalFlag || isLocalUrl;

    final thumbnailUrl = !isLocal &&
            driveFileId != null &&
            driveFileId.isNotEmpty &&
            mimeType.startsWith('image/')
        ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w800'
        : null;

    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');

    Widget contentWidget;

    // Lógica para determinar o provedor de imagem (Local ou Rede)
    ImageProvider? imageProvider;
    if (isImage) {
      if (isLocal) {
        // Tenta usar o caminho local se disponível
        final localPath =
            f['local_path'] as String? ?? f['drive_file_url'] as String?;
        if (localPath != null && localPath.startsWith('file://')) {
          final path = localPath.replaceFirst('file://', '');
          imageProvider = FileImage(File(path));
        }
      } else if (thumbnailUrl != null) {
        imageProvider = NetworkImage(thumbnailUrl);
      }
    }

    if (imageProvider != null) {
      contentWidget = GestureDetector(
        onTap: () {
          // Se for local, talvez não queira abrir no ImageViewer ou precise passar FileImage
          // Por enquanto, só abre se for URL de rede (thumbnailUrl)
          if (thumbnailUrl != null && !isLocal) {
            ImageViewer.show(
              context,
              imageUrl: thumbnailUrl,
              downloadFileName: filename,
            );
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 150,
            width: 150,
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  width: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  width: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      contentWidget = Container(
        height: 150,
        width: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          isVideo
              ? Icons.video_file
              : (isImage ? Icons.image : Icons.insert_drive_file),
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return SizedBox(
      width: 150,
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Imagem de fundo
            contentWidget,

            // Nome do arquivo na parte inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                ),
              ),
            ),

            // Badge "Design Materials" no canto superior esquerdo
            if (isDesignMaterial)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_special,
                        size: 10,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DM',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Botões de ação (Download e Delete) ou Loading Indicator
            if (!isLocal)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão de Download
                    Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onDownload(f),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.download_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    // Botão de Delete (se fornecido)
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      Material(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => onDelete!(f),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              // Indicador discreto de upload no canto (substitui o botão de download)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
