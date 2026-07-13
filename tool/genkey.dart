// One-off dev tool: generate an Ed25519 keypair for offline license signing.
// ignore_for_file: avoid_print
import 'package:cryptography/cryptography.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<void> main() async {
  final algo = Ed25519();
  final kp = await algo.newKeyPair();
  final priv = await kp.extractPrivateKeyBytes(); // 32-byte seed
  final pub = (await kp.extractPublicKey()).bytes; // 32-byte public
  print('PRIV_HEX=${hex(priv)}');
  print('PUB_HEX=${hex(pub)}');
}
