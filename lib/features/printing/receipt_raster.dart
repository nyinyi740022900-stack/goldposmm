import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../invoices/receipt_data.dart';

/// Renders formatted receipt [lines] to a monochrome-friendly bitmap sized to
/// the paper's dot width.
///
/// WHY raster: most cheap Bluetooth thermal printers ship without a Myanmar
/// font, so ESC/POS text mode prints Burmese as boxes. Rendering to an image
/// with Flutter's text engine (which has Noto/Pyidaungsu fallback) guarantees
/// Burmese renders correctly on any printer.
///
/// Latin/number columns are laid out with a monospace family so the money
/// columns stay aligned; Burmese product names fall back to a proportional
/// Myanmar font on their own left-aligned lines.
Future<img.Image> renderReceiptImage(
  List<String> lines,
  PaperSize paper, {
  double fontSize = 22,
}) async {
  final width = paper.dots;
  final text = lines.join('\n');

  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontFamily: 'monospace',
    fontSize: fontSize,
    height: 1.25,
  ))
    ..pushStyle(ui.TextStyle(
      color: const ui.Color(0xFF000000),
      fontFamily: 'monospace',
      fontSize: fontSize,
    ))
    ..addText(text);

  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: width.toDouble()));

  final height = paragraph.height.ceil() + 16;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // White background so the thermal head only burns the dark glyphs.
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  canvas.drawParagraph(paragraph, const ui.Offset(0, 8));

  final picture = recorder.endRecording();
  final uiImage = await picture.toImage(width, height);
  final bytes =
      await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  uiImage.dispose();

  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes!.buffer,
    numChannels: 4,
  );
}
