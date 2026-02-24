import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';

import 'pdf_export_io.dart' if (dart.library.html) 'pdf_export_web.dart' as platform;

final _nf = NumberFormat('#,###', 'es_CL');

class PdfExport {
  static Future<void> exportAndShare(
    BuildContext context,
    UserInput input,
    TotalesSimulacion totales,
    SimulacionAPVResponse result,
  ) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Simulación APV Chile',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Datos de entrada', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Sueldo bruto mensual: \$${_nf.format(input.sueldoBrutoMensual.round())}'),
            pw.Text('Edad actual: ${input.edadActual} · Jubilación: ${input.edadJubilacion}'),
            pw.Text('Aporte APV mensual: \$${_nf.format(input.ahorroMensualApv.round())}'),
            pw.Text('Ahorro normal mensual: \$${_nf.format(input.ahorroMensualNormal.round())}'),
            pw.SizedBox(height: 16),
            pw.Text('Resumen tributario', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Mejor régimen: ${totales.mejorRegimen}'),
            pw.Text('Ahorro fiscal anual: \$${_nf.format(totales.regimenB.ahorroFiscal.round())}'),
            pw.Text('Impuesto sin APV: \$${_nf.format(totales.regimenB.impuestoSinApv.round())}'),
            pw.Text('Impuesto con APV: \$${_nf.format(totales.regimenB.impuestoConApv.round())}'),
            pw.SizedBox(height: 16),
            pw.Text('Proyección a jubilación', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (result.proyeccionAnual.isNotEmpty) ...[
              pw.Text('Capital APV: \$${_nf.format(result.proyeccionAnual.last.capitalApv.round())}'),
              pw.Text('Capital ahorro tradicional: \$${_nf.format(result.proyeccionAnual.last.capitalAhorroTradicional.round())}'),
            ],
            pw.SizedBox(height: 12),
            pw.Text(
              'Generado con APV Simulator · ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await platform.savePdfBytes(bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
