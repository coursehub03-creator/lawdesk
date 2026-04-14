
import 'dart:math';

/// Lightweight UUID v4 generator (RFC 4122) without external packages.
String uuidV4() {
  final Random _rnd = Random.secure();
  List<int> bytes = List<int>.generate(16, (_) => _rnd.nextInt(256));

  // Per RFC 4122 section 4.4
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10

  String _hex(int b) => b.toRadixString(16).padLeft(2, '0');

  final parts = [
    for (final b in bytes) _hex(b)
  ].join();

  return '${parts.substring(0,8)}-'
         '${parts.substring(8,12)}-'
         '${parts.substring(12,16)}-'
         '${parts.substring(16,20)}-'
         '${parts.substring(20,32)}';
}
