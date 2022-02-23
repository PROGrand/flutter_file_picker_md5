import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker_extended/file_picker_extended.dart';
import 'dart:io' as dartio;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:intl/intl.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:url_launcher/url_launcher.dart';

import 'request_impl.dart';

const bucket = '<your-bucket>';

//your service account json here
const serviceAccountJson = '''
{
  "type": "service_account",
}
''';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _mediaLink;
  int _byteCount = 0;
  int _totalSize = 1;
  double _progress = 0;
  http.Client? _httpClient;

  void _uploadFile() async {
    final result = await FilePickerExtended.platform.pickFile([
      'mp4',
    ]);

    if (result == null) {
      throw Exception('No files picked or file picker was canceled');
    }

    uploadFile(
      stream: result.stream,
      md5: result.md5,
      length: result.length
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Press plus to upload'),
            RichText(
                text: TextSpan(
              children: [
                if (null != _mediaLink)
                  TextSpan(
                    text: _mediaLink,
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launch(_mediaLink!);
                      },
                  ),
              ],
            )),
            if (null != _httpClient)
              if (0 == _progress)
                const CircularProgressIndicator()
              else
                LinearProgressIndicator(value: _progress)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        tooltip: 'Upload file',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> uploadFile(
      {required crypto.Digest md5,
      required int length,
      required Stream<List<int>> stream}) async {
    setState(() {
      _byteCount = 0;
      _totalSize = length;
      _progress = 0;
    });

    setState(() {
      _mediaLink = '';
      _httpClient = http.Client();
    });

    final contentMd5 = base64.encode(md5.bytes);

    if (kDebugMode) {
      print('MD5: $md5');
      print('MD5 base 64: $contentMd5');
    }

    final dateTime = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'file_$dateTime.mp4';

    // fake server request
    final signedUrl = await generateV4SignedUrl(
      bucket: bucket,
      objectPath: '/$fileName',
      contentType: 'video/mp4',
      contentMd5: contentMd5,
      requestMethod: 'PUT',
      metadata: {
        'your_metadata': 'your_metadata_value',
        'your_metadata2': 'your_metadata_value2',
      },
    );

    final headers = <String, String>{
      dartio.HttpHeaders.contentTypeHeader: 'video/mp4',
      dartio.HttpHeaders.contentMD5Header: contentMd5,
      'x-goog-meta-your_metadata': 'your_metadata_value',
      'x-goog-meta-your_metadata2': 'your_metadata_value2',
    };


    Stream<List<int>> streamUpload = stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          _byteCount += data.length;

          setState(() {
            if (0 != _totalSize) {
              _progress = _byteCount / _totalSize;
              if (kDebugMode) {
                print('PROGRESS: ${100 * _progress}');
              }
            }
          });
        },
        handleError: (error, stack, sink) {
          throw error;
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );

    var request = RequestImpl('PUT', signedUrl, streamUpload);
    request.headers.addAll(headers);

    try {
      final res = await _httpClient!.send(request);

      if (res.statusCode == 200) {
        setState(() {
          _mediaLink = Uri(
            scheme: 'https',
            host: 'storage.googleapis.com',
            path: '$bucket${signedUrl.path}',
          ).toString();

          if (kDebugMode) {
            print(_mediaLink);
          }
        });
      } else {
        final s = await res.stream.bytesToString();
        setState(() {
          _mediaLink = s;
        });
      }
      return true;
    } catch (e) {
      setState(() {
        _mediaLink = e.toString();
      });
      return false;
    } finally {
      setState(() {
        _httpClient = null;
      });
    }
  }

  Future<Uri> generateV4SignedUrl({
    required String bucket,
    required String objectPath,
    String? contentType,
    String? contentMd5,
    required String requestMethod,
    int expiresPeriodInSeconds = 3600,
    Map<String, String> metadata = const {},
  }) async {
    final serviceAccount =
        ServiceAccountCredentials.fromJson(serviceAccountJson);

    final host = '$bucket.storage.googleapis.com';
    final headers = <String, String>{
      dartio.HttpHeaders.hostHeader: host,
      if (contentType != null) //
        dartio.HttpHeaders.contentTypeHeader: contentType,
      if (contentMd5 != null) //
        dartio.HttpHeaders.contentMD5Header: contentMd5,
      ...metadata.map((key, value) {
        return MapEntry('x-goog-meta-${key.toLowerCase()}', value);
      }),
    };

    final signedHeaders = headers.keys //
        .map((el) => el.toLowerCase())
        .sortedBy((el) => el)
        .join(';');

    final canonicalHeaders = headers.entries
        .map((e) => MapEntry(e.key.toLowerCase(), e.value))
        .sortedBy((e) => e.key)
        .map((e) => '${e.key}:${e.value}')
        .join('\n');

    final accessibleAt = DateTime.now().toUtc();
    final credDate = DateFormat('yyyyMMdd').format(accessibleAt);
    final credScope = '$credDate/auto/storage/goog4_request';
    //us-central1 instead auto?

    // careful with this DateTime - it might be setting a time in the future
    // based on your time zone
    final dateIso = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(accessibleAt);
    final queryParams = <String, String>{
      'X-Goog-Algorithm': 'GOOG4-RSA-SHA256',
      'X-Goog-Credential': '${serviceAccount.email}/$credScope',
      'X-Goog-Date': dateIso,
      'X-Goog-Expires': '$expiresPeriodInSeconds',
      'X-Goog-SignedHeaders': signedHeaders,
    };

    final canonicalParams = queryParams
        .map((key, value) =>
            MapEntry(Uri.encodeComponent(key), Uri.encodeComponent(value)))
        .entries
        .sortedBy((e) => e.key)
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final canonicalRequest = [
      requestMethod,
      objectPath,
      canonicalParams,
      canonicalHeaders,
      '',
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final hash =
        crypto.sha256.convert(utf8.encode(canonicalRequest)).toString();
    final signBlob =
        utf8.encode(['GOOG4-RSA-SHA256', dateIso, credScope, hash].join('\n'));

    final privateKey = RSAPrivateKey(
      serviceAccount.privateRSAKey.n,
      serviceAccount.privateRSAKey.d,
      serviceAccount.privateRSAKey.p,
      serviceAccount.privateRSAKey.q,
    );
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature =
        signer.generateSignature(Uint8List.fromList(signBlob)) as RSASignature;

    return Uri.parse('https://$host$objectPath').replace(
        query:
            '$canonicalParams&x-goog-signature=${hex.encode(signature.bytes)}');
  }
}
