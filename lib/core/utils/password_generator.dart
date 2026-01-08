import 'dart:math';

/// Random 4-digit numeric password generator
String generateRoomPassword({int length = 4}) {
  final random = Random();
  const chars = '0123456789'; // Sadece rakamlar
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
