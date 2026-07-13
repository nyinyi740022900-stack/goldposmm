import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/features/license/license_status.dart';
import 'package:mm_pos/features/license/offline_license.dart';

void main() {
  late Ed25519 algo;
  late SimpleKeyPair kp;
  late String pubHex;

  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  String b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

  /// Signs a payload the same way the admin Edge Function does.
  Future<String> mint(Map<String, dynamic> payload) async {
    final payloadB64 = b64url(utf8.encode(jsonEncode(payload)));
    final msg = utf8.encode('MMPOS1.$payloadB64');
    final sig = await algo.sign(msg, keyPair: kp);
    return 'MMPOS1.$payloadB64.${b64url(sig.bytes)}';
  }

  setUp(() async {
    algo = Ed25519();
    kp = await algo.newKeyPair();
    pubHex = hex((await kp.extractPublicKey()).bytes);
  });

  int future() =>
      DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch ~/
      1000;

  test('a valid token verifies and yields the license', () async {
    final token = await mint({
      'shop_id': 'shop-1',
      'shop_name': 'Zay Shae',
      'plan': 'yearly',
      'exp': future(),
      'iat': 0,
    });
    final lic = await OfflineLicense.verify(token, 'dev-1', publicKeyHex: pubHex);
    expect(lic.shopId, 'shop-1');
    expect(lic.plan, LicensePlan.yearly);
    expect(lic.expiresAt.isAfter(DateTime.now()), isTrue);
  });

  test('a tampered payload fails the signature', () async {
    final token = await mint({'shop_id': 's', 'plan': 'monthly', 'exp': future()});
    final parts = token.split('.');
    // Swap the payload for a different one, keep the signature.
    final forged =
        'MMPOS1.${base64Url.encode(utf8.encode('{"shop_id":"evil","exp":9999999999}')).replaceAll('=', '')}.${parts[2]}';
    expect(
      () => OfflineLicense.verify(forged, 'dev-1', publicKeyHex: pubHex),
      throwsA(isA<OfflineLicenseException>()),
    );
  });

  test('a device-bound token rejects a different device', () async {
    final token = await mint({
      'shop_id': 's',
      'plan': 'monthly',
      'exp': future(),
      'device_id': 'dev-A',
    });
    expect(
      () => OfflineLicense.verify(token, 'dev-B', publicKeyHex: pubHex),
      throwsA(predicate(
          (e) => e is OfflineLicenseException && e.code == 'device_mismatch')),
    );
    // Matching device is fine.
    final lic =
        await OfflineLicense.verify(token, 'dev-A', publicKeyHex: pubHex);
    expect(lic.shopId, 's');
  });

  test('looksLikeToken detects the prefix', () {
    expect(OfflineLicense.looksLikeToken('MMPOS1.abc.def'), isTrue);
    expect(OfflineLicense.looksLikeToken('MMPOS-1234-5678-9ABC'), isFalse);
  });
}
