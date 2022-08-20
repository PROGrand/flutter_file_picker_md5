import 'dart:io';

import 'package:async/async.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../file_picker_extended.dart';

class FilePickerExtendedNoweb extends FilePickerExtended {
  @override
  Future<FilePickResult?> pickFile({
    List<String>? allowedExtensions,
    void Function(bool done, double progress)? onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? const [],
        withData: false,
        withReadStream: true,
        allowCompression: false,
        allowMultiple: false);

    if (result == null || result.files.isEmpty) {
      throw Exception('No files picked or file picker was canceled');
    }

    if (result.files.isNotEmpty) {
      return FilePickResult(
        length: result.files.first.size,
        stream: result.files.first.readStream!,
        md5: await calculateMD5(File(result.files.first.path!).openRead(),
            onProgress: onProgress),
        fileName: result.files.first.name,
      );
    }

    throw Exception('No files picked or file picker was canceled');
  }

  static Future<Digest> calculateMD5(
    Stream<List<int>> stream, {
    void Function(bool done, double progress)? onProgress,
  }) async {
    var size = await stream.length;

    final startTime = kDebugMode ? DateTime.now().millisecondsSinceEpoch : 0;

    final reader = ChunkedStreamReader(stream);
    const chunkSize = 4096 * 64;
    var output = AccumulatorSink<Digest>();
    var input = md5.startChunkedConversion(output);

    var readed = 0;

    try {
      while (true) {
        final chunk = await reader.readChunk(chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        input.add(chunk);

        readed += chunk.length;

        if (null != onProgress) {
          onProgress(false, readed.toDouble() / size);
        }
      }
    } finally {
      reader.cancel();
    }

    input.close();

    if (kDebugMode) {
      final delta = DateTime.now().millisecondsSinceEpoch - startTime;
      print('MD5 time $delta');
    }

    if (null != onProgress) {
      onProgress(true, 1.0);
    }

    return output.events.single;
  }
}
