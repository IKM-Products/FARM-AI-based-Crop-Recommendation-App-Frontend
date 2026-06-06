import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'result_screen.dart';

class CropFormScreen extends StatefulWidget {
  const CropFormScreen({super.key});

  @override
  State<CropFormScreen> createState() => _CropFormScreenState();
}

class _CropFormScreenState extends State<CropFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  bool _isFetchingWeather = false;

  // --- Unit Conversion State ---
  bool _isMetric = true;

  // Render Backend Production Server URL Base
  final String apiUrl = "https://farm-ai-based-crop-recommendation-backend.onrender.com";

  final TextEditingController _nController = TextEditingController();
  final TextEditingController _pController = TextEditingController();
  final TextEditingController _kController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _rainfallController = TextEditingController();

  @override
  void dispose() {
    _nController.dispose();
    _pController.dispose();
    _kController.dispose();
    _tempController.dispose();
    _humidityController.dispose();
    _phController.dispose();
    _rainfallController.dispose();
    super.dispose();
  }

  // Helper to convert inputs back to Metric before sending to the AI model
  Map<String, double> _getProcessedData() {
    double temp = double.parse(_tempController.text);
    double rain = double.parse(_rainfallController.text);

    if (!_isMetric) {
      // Imperial to Metric: (F - 32) * 5/9
      temp = (temp - 32) * 5 / 9;
      // Imperial to Metric: Inches * 25.4
      rain = rain * 25.4;
    }

    return {
      "N": double.parse(_nController.text),
      "P": double.parse(_pController.text),
      "K": double.parse(_kController.text),
      "temperature": temp,
      "humidity": double.parse(_humidityController.text),
      "ph": double.parse(_phController.text),
      "rainfall": rain,
    };
  }

  void _autoFill() {
    _nController.text = "90";
    _pController.text = "42";
    _kController.text = "43";
    _phController.text = "6.5";
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("NPK & pH Auto-filled!")),
    );
  }

  Future<void> _fetchWeatherData() async {
    setState(() => _isFetchingWeather = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final weatherUrl = "https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m&daily=precipitation_sum&timezone=auto";

      final response = await http.get(Uri.parse(weatherUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          double rawTemp = data['current']['temperature_2m'];
          double rawRain = data['daily']['precipitation_sum'][0];

          // If user is in Imperial mode, convert the weather data labels
          if (!_isMetric) {
            rawTemp = (rawTemp * 9 / 5) + 32; // C to F
            rawRain = rawRain / 25.4;        // mm to inches
          }

          _tempController.text = rawTemp.toStringAsFixed(1);
          _humidityController.text = data['current']['relative_humidity_2m'].toString();
          _rainfallController.text = rawRain.toStringAsFixed(2);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Live weather data updated!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not fetch weather: $e")),
      );
    } finally {
      setState(() => _isFetchingWeather = false);
    }
  }

  // Optimized Execution Workflow handles safe integer extraction and diagnostic prints
  Future<void> _handlePrediction() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);

      try {
        final processedData = _getProcessedData();

        // 🔍 DEBUG PRINT 1: Check what your Flutter app is sending out
        print("🚀 EXPORTING JSON TO BACKEND: ${jsonEncode(processedData)}");

        // 🌟 Fix: Combined base URL with standard FastAPI target endpoint path mapping
        final response = await http.post(
          Uri.parse("$apiUrl/predict"),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode(processedData),
        ).timeout(const Duration(seconds: 30)); // Extended timeout for Render free-tier cold spins

        // 🔍 DEBUG PRINT 2: Check what your Python model server responds with
        print("📥 SERVER RESPONSE STATUS: ${response.statusCode}");
        print("📥 SERVER RESPONSE BODY: ${response.body}");

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          String crop = result['prediction'] ?? 'Unknown';

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('history')
                .add({
              'crop': crop,
              'n': int.tryParse(_nController.text) ?? 0,
              'p': int.tryParse(_pController.text) ?? 0,
              'k': int.tryParse(_kController.text) ?? 0,
              'ph': double.tryParse(_phController.text) ?? 0.0,
              'unit_system': _isMetric ? "Metric" : "Imperial",
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  predictedCrop: crop,
                  soilData: {
                    "N": _nController.text,
                    "P": _pController.text,
                    "K": _kController.text,
                    "pH": _phController.text,
                    "Temp": "${_tempController.text}${_isMetric ? '°C' : '°F'}",
                    "Rain": "${_rainfallController.text}${_isMetric ? 'mm' : 'in'}",
                  },
                ),
              ),
            );
          }
        } else {
          throw Exception("Server returned status code: ${response.statusCode}");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Prediction Failed: $e"),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Soil Data Input", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isFetchingWeather
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.location_on),
            onPressed: _isFetchingWeather ? null : _fetchWeatherData,
          ),
          IconButton(icon: const Icon(Icons.auto_fix_high), onPressed: _autoFill)
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50), Color(0xFF81C784)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text("Enter Soil Details", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 10),

                    // --- UNIT TOGGLE ROW ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            "Imperial (in/°F)",
                            style: GoogleFonts.poppins(fontSize: 12, color: !_isMetric ? Colors.green.shade700 : Colors.grey)
                        ),
                        Switch(
                          value: _isMetric,
                          activeColor: Colors.green.shade700,
                          onChanged: (val) => setState(() => _isMetric = val),
                        ),
                        Text(
                            "Metric (mm/°C)",
                            style: GoogleFonts.poppins(fontSize: 12, color: _isMetric ? Colors.green.shade700 : Colors.grey)
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    _buildInput(_nController, "Nitrogen (N)", Icons.science),
                    _buildInput(_pController, "Phosphorus (P)", Icons.science_outlined),
                    _buildInput(_kController, "Potassium (K)", Icons.biotech),

                    // Dynamic Labels for Temp and Rainfall
                    _buildInput(_tempController, "Temperature (${_isMetric ? '°C' : '°F'})", Icons.thermostat),
                    _buildInput(_humidityController, "Humidity (%)", Icons.cloud),
                    _buildInput(_phController, "pH Level", Icons.water_drop),
                    _buildInput(_rainfallController, "Rainfall (${_isMetric ? 'mm' : 'in'})", Icons.umbrella),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePrediction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("PREDICT BEST CROP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
      ),
    );
  }
}