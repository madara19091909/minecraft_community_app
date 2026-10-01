import 'dart:typed_data';

class PickedImage {
  const PickedImage(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension; // jpg | png | webp

  String get contentType => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
