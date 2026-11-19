import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ReceiptImageService {
  ReceiptImageService._();
  static final instance = ReceiptImageService._();

  static const maxImageDimension = 1600;
  static const maxBase64Length = 700 * 1024;

  Future<String> encodeForFirestore(Uint8List bytes) =>
      compute(_encodeReceipt, bytes);
}

String _encodeReceipt(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on RangeError {
    throw const FormatException(
      'File yang dipilih bukan gambar yang didukung.',
    );
  }
  if (decoded == null) {
    throw const FormatException(
      'File yang dipilih bukan gambar yang didukung.',
    );
  }

  final oriented = img.bakeOrientation(decoded);
  final longestSide = math.max(oriented.width, oriented.height);
  for (
    var maxSide = ReceiptImageService.maxImageDimension;
    maxSide >= 320;
    maxSide = maxSide * 3 ~/ 4
  ) {
    final scale = math.min(1.0, maxSide / longestSide);
    final resized = scale < 1
        ? img.copyResize(
            oriented,
            width: math.max(1, (oriented.width * scale).round()),
            height: math.max(1, (oriented.height * scale).round()),
            interpolation: img.Interpolation.average,
          )
        : oriented;

    for (final quality in [80, 65, 50]) {
      final base64Image = base64Encode(
        img.encodeJpg(resized, quality: quality),
      );
      if (base64Image.length <= ReceiptImageService.maxBase64Length) {
        return base64Image;
      }
    }
  }

  throw StateError(
    'Foto nota terlalu besar untuk Firestore. Pilih foto yang lebih kecil.',
  );
}
