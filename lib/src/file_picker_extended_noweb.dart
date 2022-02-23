import 'package:async/async.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import '../file_picker_extended.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerExtendedNoweb extends FilePickerExtended {
  @override
  Future<FilePickResult?> pickFile(List<String> allowedExtensions) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
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
          md5: await calculateMD5(File(result.files.first.path!).openRead()));
    }

    throw Exception('No files picked or file picker was canceled');
  }

  static Future<Digest> calculateMD5(Stream<List<int>> stream) async {
    final startTime = kDebugMode ? DateTime.now().millisecondsSinceEpoch : 0;

    final reader = ChunkedStreamReader(stream);
    const chunkSize = 4096 * 64;
    var output = AccumulatorSink<Digest>();
    var input = md5.startChunkedConversion(output);

    try {
      while (true) {
        final chunk = await reader.readChunk(chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        input.add(chunk);
      }
    } finally {
      reader.cancel();
    }

    input.close();

    if (kDebugMode) {
      final delta = DateTime.now().millisecondsSinceEpoch - startTime;
      print('MD5 time $delta');
    }

    return output.events.single;
  }
}
