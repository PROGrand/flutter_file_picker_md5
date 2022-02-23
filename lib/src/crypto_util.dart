import 'package:crypto/crypto.dart' as crypto;
import 'dart:html';

import 'package:flutter/foundation.dart';

class MD5Util {
  static Future<crypto.Digest> calculate(File file) async {
    var innerSink = DigestSink();
    var outerSink = crypto.md5.startChunkedConversion(innerSink);

    final startTime = kDebugMode ? DateTime.now().millisecondsSinceEpoch : 0;
    final reader = FileReader();
    const bufferSize = 4096 * 64;
    var start = 0;

    while (start < file.size) {
      final end =
          start + bufferSize > file.size ? file.size : start + bufferSize;
      final blob = file.slice(start, end);
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      outerSink.add(reader.result as List<int>);
      start += bufferSize;
    }

    if (kDebugMode) {
      final delta = DateTime.now().millisecondsSinceEpoch - startTime;
      print('MD5 time $delta');
    }

    outerSink.close();

    return innerSink.value;
  }
}

/// A sink used to get a digest value out of `Hash.startChunkedConversion`.
class DigestSink extends Sink<crypto.Digest> {
  /// The value added to the sink.
  ///
  /// A value must have been added using [add] before reading the `value`.
  crypto.Digest get value => _value!;

  crypto.Digest? _value;

  /// Adds [value] to the sink.
  ///
  /// Unlike most sinks, this may only be called once.
  @override
  void add(crypto.Digest value) {
    if (_value != null) throw StateError('add may only be called once.');
    _value = value;
  }

  @override
  void close() {
    if (_value == null) throw StateError('add must be called once.');
  }
}
