import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ExportShareStatus { success, cancelled }

class ExportShareResult {
  const ExportShareResult({
    required this.status,
    this.file,
    required this.usedShareSheet,
  });

  final ExportShareStatus status;
  final File? file;
  final bool usedShareSheet;
}

class ShareService {
  const ShareService();

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _isMobileShareTarget => Platform.isIOS || Platform.isAndroid;

  Future<File> saveExportFile({
    required String fileName,
    required String content,
  }) async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory exportsDir = Directory(
      p.join(documentsDir.path, 'exports'),
    );

    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final String filePath = p.join(exportsDir.path, fileName);
    final File file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  Future<ExportShareResult> saveExportFileWithPicker({
    required String fileName,
    required String content,
  }) async {
    if (_isMobileShareTarget) {
      final File tempFile = await saveExportFile(
        fileName: fileName,
        content: content,
      );
      final ShareResult shareResult = await Share.shareXFiles(<XFile>[
        XFile(tempFile.path),
      ]);

      if (shareResult.status == ShareResultStatus.dismissed) {
        return const ExportShareResult(
          status: ExportShareStatus.cancelled,
          usedShareSheet: true,
        );
      }

      return ExportShareResult(
        status: ExportShareStatus.success,
        file: tempFile,
        usedShareSheet: true,
      );
    }

    if (!_isDesktop) {
      final File file = await saveExportFile(
        fileName: fileName,
        content: content,
      );
      return ExportShareResult(
        status: ExportShareStatus.success,
        file: file,
        usedShareSheet: false,
      );
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
      return const ExportShareResult(
        status: ExportShareStatus.cancelled,
        usedShareSheet: false,
      );
    }

    final String finalPath = _ensureExpectedExtension(
      path: selectedPath,
      expectedExtension: extension,
    );

    final File file = File(finalPath);
    await file.create(recursive: true);
    await file.writeAsString(content);
    return ExportShareResult(
      status: ExportShareStatus.success,
      file: file,
      usedShareSheet: false,
    );
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
