import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ShareService {
  const ShareService();

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<File> saveExportFile({
    required String fileName,
    required String content,
  }) async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory exportsDir = Directory(p.join(documentsDir.path, 'exports'));

    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final String filePath = p.join(exportsDir.path, fileName);
    final File file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  Future<File?> saveExportFileWithPicker({
    required String fileName,
    required String content,
  }) async {
    if (!_isDesktop) {
      return saveExportFile(fileName: fileName, content: content);
    }

    final String extension = _extractExtension(fileName);
    final List<XTypeGroup> acceptedTypeGroups = extension.isEmpty
        ? const <XTypeGroup>[]
        : <XTypeGroup>[
            XTypeGroup(
              label: '${extension.toUpperCase()} files',
              extensions: <String>[extension],
            ),
          ];

    final FileSaveLocation? selectedLocation = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: acceptedTypeGroups,
    );

    final String? selectedPath = selectedLocation?.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return null;
    }

    final String finalPath = _ensureExpectedExtension(
      path: selectedPath,
      expectedExtension: extension,
    );

    final File file = File(finalPath);
    await file.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  String _extractExtension(String fileName) {
    final String extensionWithDot = p.extension(fileName).toLowerCase();
    if (extensionWithDot.startsWith('.') && extensionWithDot.length > 1) {
      return extensionWithDot.substring(1);
    }
    return '';
  }

  String _ensureExpectedExtension({
    required String path,
    required String expectedExtension,
  }) {
    if (expectedExtension.isEmpty) {
      return path;
    }

    final String currentExtension = p.extension(path).toLowerCase();
    final String expectedWithDot = '.${expectedExtension.toLowerCase()}';

    if (currentExtension == expectedWithDot) {
      return path;
    }

    return '$path$expectedWithDot';
  }
}