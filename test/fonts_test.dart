import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  test('List comic fonts', () {
    var fonts = GoogleFonts.asMap().keys
        .where((k) => k.toLowerCase().contains('comic'))
        .toList();
    File('fonts_out.txt').writeAsStringSync(fonts.join(', '));
  });
}
