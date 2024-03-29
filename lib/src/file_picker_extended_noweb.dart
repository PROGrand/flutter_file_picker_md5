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
    ValueNotifier<bool>? canceled,
    bool returnStream = true,
    bool calcMD5 = true,
    bool returnBlob = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? const [],
        withData: false,
        withReadStream: returnStream,
        allowCompression: false,
        allowMultiple: false);

    if (result == null || result.files.isEmpty) {
      throw Exception('No files picked or file picker was canceled');
    }

    if (result.files.isNotEmpty) {
      var res = FilePickResult(
        length: result.files.first.size,
        stream: returnStream ? result.files.first.readStream! : null,
        blob: result.files.first,
        md5: await calculateMD5(
          stream: File(result.files.first.path!).openRead(),
          size: result.files.first.size,
          onProgress: onProgress,
          canceled: canceled,
        ),
        fileName: result.files.first.name,
      );

      if (!(canceled?.value ?? false || null == res.md5)) {
        return res;
      }
    }

    return null;
  }

  static Future<Digest?> calculateMD5({
    required Stream<List<int>> stream,
    required int size,
    void Function(bool done, double progress)? onProgress,
    ValueNotifier<bool>? canceled,
  }) async {
    final startTime = kDebugMode ? DateTime.now().millisecondsSinceEpoch : 0;

    final reader = ChunkedStreamReader(stream);
    const chunkSize = 4096 * 64;
    var output = AccumulatorSink<Digest>();
    var input = md5.startChunkedConversion(output);

    var readed = 0;

    try {
      while (!(canceled?.value ?? false)) {
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
      input.close();
    }

    if (canceled?.value ?? false) {
      return null;
    }

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
