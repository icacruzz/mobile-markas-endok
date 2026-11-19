import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uts_markas_endok/services/receipt_image_service.dart';

void main() {
  test('encodes a resized receipt within the Firestore size budget', () async {
    final original = img.encodeJpg(img.Image(width: 2400, height: 1800));
    final encoded = await ReceiptImageService.instance.encodeForFirestore(
      original,
    );
    final decoded = img.decodeImage(base64Decode(encoded));

    expect(
      encoded.length,
      lessThanOrEqualTo(ReceiptImageService.maxBase64Length),
    );
    expect(decoded, isNotNull);
    expect(
      decoded!.width,
      lessThanOrEqualTo(ReceiptImageService.maxImageDimension),
    );
    expect(
      decoded.height,
      lessThanOrEqualTo(ReceiptImageService.maxImageDimension),
    );
  });

  test('rejects bytes that are not a supported image', () async {
    await expectLater(
      ReceiptImageService.instance.encodeForFirestore(
        Uint8List.fromList([1, 2, 3]),
      ),
      throwsFormatException,
    );
  });
}
