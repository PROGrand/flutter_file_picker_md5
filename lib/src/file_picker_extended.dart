import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'file_picker_extended_noweb.dart';

class FilePickResult {
  FilePickResult({required this.length, required this.stream, required this.md5});

  final int length;
  final Stream<List<int>> stream;
  final Digest md5;
}

abstract class FilePickerExtended extends PlatformInterface {
  FilePickerExtended() : super(token: _token);

  static final Object _token = Object();

  static late FilePickerExtended _instance = FilePickerExtended._setPlatform();

  static FilePickerExtended get platform => _instance;

  static set platform(FilePickerExtended instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  factory FilePickerExtended._setPlatform() {
    if (!kIsWeb) {
      return FilePickerExtendedNoweb();
    } else {
      throw UnimplementedError(
        'The current platform "${Platform.operatingSystem}" is not supported by this plugin.',
      );
    }
  }

  //[
  //           'mp4',
  //         ]
  Future<FilePickResult?> pickFile(List<String> allowedExtensions) async =>
      throw UnimplementedError('pickFile() has not been implemented.');
}
