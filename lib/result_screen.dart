import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResultScreen extends StatelessWidget {
  final String predictedCrop;
  final Map<String, dynamic> soilData;

  const ResultScreen({
    super.key,
    required this.predictedCrop,
    required this.soilData,
  });

  // 1. PDF LOGIC
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Crop Prediction Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text("Recommended Crop: ${predictedCrop.toUpperCase()}"),
            pw.SizedBox(height: 10),
            pw.Text("Soil Data Used:"),
            ...soilData.entries.map((e) => pw.Text("${e.key}: ${e.value}")),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // 2. SHARE LOGIC
  void _shareResult() {
    String shareText = "My Soil Test Result: \n"
        "Recommended Crop: ${predictedCrop.toUpperCase()}\n"
        "Data: $soilData";
    Share.share(shareText);
  }

  // 3. BADGE LOGIC (NPK status)
  Widget _getBadge(String key, dynamic value) {
    double val = double.tryParse(value.toString()) ?? 0.0;
    String status;
    Color color;

    if (key == 'N') {
      if (val < 50) { status = "Low"; color = Colors.red; }
      else if (val < 100) { status = "Optimal"; color = Colors.green; }
      else { status = "High"; color = Colors.orange; }
    } else if (key == 'P' || key == 'K') {
      if (val < 30) { status = "Low"; color = Colors.red; }
      else if (val < 70) { status = "Optimal"; color = Colors.green; }
      else { status = "High"; color = Colors.orange; }
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // 4. FERTILIZER LOGIC
  String getFertilizerTip(double n, double p, double k) {
    if (n < 50) return "Nitrogen (N) is low. Apply Urea or Ammonium Nitrate or organic compost to boost growth.";
    if (p < 30) return "Phosphorus (P) is low. Consider using DAP or Bone Meal or Superphosphate for root health.";
    if (k < 30) return "Potassium (K) is low. Muriate of Potash (MOP) is recommended.";
    return "NPK levels are well-balanced! Maintain this with general-purpose organic fertilizer.";
  }

  double _parseSoilValue(dynamic value) => double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    // Parse values for the tip logic
    final nVal = _parseSoilValue(soilData['N']);
    final pVal = _parseSoilValue(soilData['P']);
    final kVal = _parseSoilValue(soilData['K']);
    final fertilizerTip = getFertilizerTip(nVal, pVal, kVal);

    return Scaffold(
      appBar: AppBar(
        title: Text("Recommendation", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.green.shade900,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generatePdf),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareResult),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              // Result Card (Crop Name)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                child: Column(
                  children: [
                    const Icon(Icons.eco, size: 60, color: Colors.green),
                    const SizedBox(height: 10),
                    Text(predictedCrop.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                    Text("Best crop for your soil", style: GoogleFonts.poppins(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FERTILIZER TIP CARD (The missing piece!)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(fertilizerTip,
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Analysis Card with Badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Soil Analysis Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: soilData.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            children: [
                              Text("${entry.key}: ${entry.value}", style: GoogleFonts.poppins(fontSize: 13)),
                              const SizedBox(height: 4),
                              _getBadge(entry.key, entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text("NEW ANALYSIS", style: GoogleFonts.poppins(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}