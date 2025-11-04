import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

/// Widget reutilizável para seleção de avatar
/// Exibe preview e permite selecionar nova imagem
class AvatarPicker extends StatelessWidget {
  final File? avatarFile;
  final String? avatarUrl;
  final VoidCallback onPick;
  final double size;

  const AvatarPicker({
    super.key,
    this.avatarFile,
    this.avatarUrl,
    required this.onPick,
    this.size = 100,
  });

  static Future<File?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundImage: avatarFile != null
                  ? FileImage(avatarFile!)
                  : avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
              child: avatarFile == null && avatarUrl == null
                  ? Icon(Icons.person, size: size / 2)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconOnlyButton(
                  icon: Icons.camera_alt,
                  iconSize: 18,
                  iconColor: Theme.of(context).colorScheme.onPrimary,
                  onPressed: onPick,
                  padding: EdgeInsets.zero,
                  tooltip: 'Alterar avatar',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Clique para alterar',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

