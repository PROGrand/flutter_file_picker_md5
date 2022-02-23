import 'package:http/http.dart' as http;

class RequestImpl extends http.BaseRequest {
  final Stream<List<int>> _stream;

  RequestImpl(String method, Uri url, [Stream<List<int>>? stream])
      : _stream = stream ?? Stream.fromIterable([]),
        super(method, url);

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_stream);
  }
}
