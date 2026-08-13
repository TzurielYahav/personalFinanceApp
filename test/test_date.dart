import 'package:intl/intl.dart';

void main() {
  var d1 = DateTime(28, 6, 4);
  var d2 = DateTime.tryParse("04/06/28");
  print(DateFormat.yMMMd().format(d1));
  
  var parts = "04/06/28".split(RegExp(r'[/.-]'));
  var parsed = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
  print(DateFormat.yMMMd().format(parsed));

  var parts2 = "04/06/2024".split(RegExp(r'[/.-]'));
  var parsed2 = DateTime(int.parse(parts2[2]), int.parse(parts2[0]), int.parse(parts2[1]));
  print(DateFormat.yMMMd().format(parsed2));
}
