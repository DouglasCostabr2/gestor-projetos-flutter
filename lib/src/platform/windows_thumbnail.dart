import 'dart:io';
import 'dart:typed_data';

/// Windows thumbnail helper (stub).
/// We keep this stub to avoid breaking builds while we request permission
/// to add FFI dependencies and wire up the full implementation.
Future<Uint8List?> getWindowsThumbnailPng(String filePath, {int size = 200}) async {
  if (!Platform.isWindows) return null;
  return null;
}
