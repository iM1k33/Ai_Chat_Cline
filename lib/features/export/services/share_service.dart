import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ShareService {
  const ShareService();

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
}