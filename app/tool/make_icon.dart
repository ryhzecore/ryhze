import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final symbol = img.decodePng(
    File('assets/brand/symbol.png').readAsBytesSync(),
  )!;
  final icon = img.Image(width: 1024, height: 1024);
  img.fill(icon, color: img.ColorRgb8(9, 9, 12));
  final scaled = img.copyResize(
    symbol,
    width: 640,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    icon,
    scaled,
    dstX: (1024 - scaled.width) ~/ 2,
    dstY: (1024 - scaled.height) ~/ 2,
  );
  File('assets/brand/app-icon.png').writeAsBytesSync(img.encodePng(icon));
}
