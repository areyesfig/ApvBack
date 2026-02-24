import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> savePdfBytes(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/simulacion_apv.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Simulación APV Chile',
    text: 'Resumen de mi simulación APV',
  );
}
