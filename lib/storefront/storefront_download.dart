import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser file download for [bytes]. Web-only — this file is
/// only ever compiled as part of the storefront web entrypoint, never the
/// mobile app, so browser APIs are safe here.
void downloadBytes(Uint8List bytes, String filename,
    {String mimeType = 'image/png'}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}
