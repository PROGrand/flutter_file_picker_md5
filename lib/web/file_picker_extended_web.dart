import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';


import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import '../file_picker_extended.dart';
import '../src/crypto_util.dart';


class FilePickerResult {
  const FilePickerResult(this.files, this.files2);

  /// Picked files.
  final List<PlatformFile> files;
  final List<File> files2;

  /// If this pick contains only a single resource.
  bool get isSinglePick => files.length == 1;

  /// The length of picked files.
  int get count => files.length;

  /// A `List<String>` containing all paths from picked files.
  ///
  /// This may or not be available and will typically reference cached copies of
  /// original files (which can be accessed through its URI property).
  ///
  /// Only available on IO. Throws `UnsupportedError` on Web.
  List<String?> get paths => files
      .map((file) => kIsWeb
          ? throw UnsupportedError(
              'Picking paths is unsupported on Web. Please, use bytes property instead.')
          : file.path)
      .toList();

  /// A `List<String>` containing all names from picked files with its extensions.
  List<String?> get names => files.map((file) => file.name).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is FilePickerResult && listEquals(other.files, files);
  }

  @override
  int get hashCode => files.hashCode;

  @override
  String toString() => 'FilePickerResult(files: $files)';
}

class FilePickerExtendedWeb extends FilePickerExtended {
  late Element _target;
  final String _kFilePickerInputsDomId = '__file_picker_web-file-input';

  final int _readStreamChunkSize = 1000 * 1000; // 1 MB

  static final FilePickerExtendedWeb platform = FilePickerExtendedWeb._();

  static void registerWith(Registrar registrar) {
    FilePickerExtended.platform = platform;
  }

  FilePickerExtendedWeb._() {
    _target = _ensureInitialized(_kFilePickerInputsDomId);
  }

  /// Initializes a DOM container where we can host input elements.
  Element _ensureInitialized(String id) {
    Element? target = querySelector('#$id');
    if (target == null) {
      final Element targetElement = Element.tag('flt-file-picker-inputs')
        ..id = id;

      querySelector('body')!.children.add(targetElement);
      target = targetElement;
    }
    return target;
  }


  @override
  Future<FilePickResult?> pickFile(List<String> allowedExtensions) async {
    final result = await FilePickerExtendedWeb.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: false,
        withReadStream: true,
        allowCompression: false,
        allowMultiple: false);

    if (result == null || result.files.isEmpty || result.files2.isEmpty) {
      throw Exception('No files picked or file picker was canceled');
    }

    if (result.files.isNotEmpty) {
      return FilePickResult(
          length: result.files.first.size,
          stream: result.files.first.readStream!,
          md5: await MD5Util.calculate(result.files2.first));
    }

    throw Exception('No files picked or file picker was canceled');
  }

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    bool withData = true,
    bool withReadStream = false,
    bool lockParentWindow = false,
  }) async {
    if (type != FileType.custom && (allowedExtensions?.isNotEmpty ?? false)) {
      throw Exception(
          'You are setting a type [$type]. Custom extension filters are only allowed with FileType.custom, please change it or remove filters.');
    }

    final Completer<List<PlatformFile>?> filesCompleter =
        Completer<List<PlatformFile>?>();
    final Completer<List<File>?> filesCompleter2 = Completer<List<File>?>();

    String accept = _fileType(type, allowedExtensions);
    InputElement uploadInput = FileUploadInputElement() as InputElement;
    uploadInput.draggable = true;
    uploadInput.multiple = allowMultiple;
    uploadInput.accept = accept;

    bool changeEventTriggered = false;

    if (onFileLoading != null) {
      onFileLoading(FilePickerStatus.picking);
    }

    void changeEventListener(e) {
      if (changeEventTriggered) {
        return;
      }
      changeEventTriggered = true;

      final List<File> files = uploadInput.files!;
      final List<PlatformFile> pickedFiles = [];

      void addPickedFile(
        File file,
        Uint8List? bytes,
        String? path,
        Stream<List<int>>? readStream,
      ) {
        pickedFiles.add(PlatformFile(
          name: file.name,
          path: path,
          size: bytes != null ? bytes.length : file.size,
          bytes: bytes,
          readStream: readStream,
        ));

        if (pickedFiles.length >= files.length) {
          if (onFileLoading != null) {
            onFileLoading(FilePickerStatus.done);
          }
          filesCompleter.complete(pickedFiles);
          filesCompleter2.complete(files);
        }
      }

      for (File file in files) {
        if (withReadStream) {
          addPickedFile(file, null, null, _openFileReadStream(file));
          continue;
        }

        if (!withData) {
          final FileReader reader = FileReader();
          reader.onLoadEnd.listen((e) {
            addPickedFile(file, null, reader.result as String?, null);
          });
          reader.readAsDataUrl(file);
          continue;
        }

        final FileReader reader = FileReader();
        reader.onLoadEnd.listen((e) {
          addPickedFile(file, reader.result as Uint8List?, null, null);
        });
        reader.readAsArrayBuffer(file);
      }
    }

    void cancelledEventListener(_) {
      window.removeEventListener('focus', cancelledEventListener);

      // This listener is called before the input changed event,
      // and the `uploadInput.files` value is still null
      // Wait for results from js to dart
      Future.delayed(const Duration(milliseconds: 500)).then((value) {
        if (!changeEventTriggered) {
          changeEventTriggered = true;
          filesCompleter.complete(null);
          filesCompleter2.complete(null);
        }
      });
    }

    uploadInput.onChange.listen(changeEventListener);
    uploadInput.addEventListener('change', changeEventListener);

    // Listen focus event for cancelled
    window.addEventListener('focus', cancelledEventListener);

    //Add input element to the page body
    _target.children.clear();
    _target.children.add(uploadInput);
    uploadInput.click();

    final List<PlatformFile>? files = await filesCompleter.future;
    final List<File>? files2 = await filesCompleter2.future;

    return files == null || files2 == null
        ? null
        : FilePickerResult(files, files2);
  }

  static String _fileType(FileType type, List<String>? allowedExtensions) {
    switch (type) {
      case FileType.any:
        return '';

      case FileType.audio:
        return 'audio/*';

      case FileType.image:
        return 'image/*';

      case FileType.video:
        return 'video/*';

      case FileType.media:
        return 'video/*|image/*';

      case FileType.custom:
        return allowedExtensions!
            .fold('', (prev, next) => '${prev.isEmpty ? '' : '$prev,'} .$next');
    }
  }

  Stream<List<int>> _openFileReadStream(File file) async* {
    final reader = FileReader();

    int start = 0;
    while (start < file.size) {
      final end = start + _readStreamChunkSize > file.size
          ? file.size
          : start + _readStreamChunkSize;
      final blob = file.slice(start, end);
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      yield reader.result as List<int>;
      start += _readStreamChunkSize;
    }
  }
}
