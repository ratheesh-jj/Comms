import 'package:google_fonts/google_fonts.dart';

void main() {
  var fonts = GoogleFonts.asMap().keys
      .where((k) => k.toLowerCase().contains('comic'))
      .toList();
  print(fonts);
}
