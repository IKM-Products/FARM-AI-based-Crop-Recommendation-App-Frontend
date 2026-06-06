import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Function to clear all history for the current user
  Future<void> _clearHistory(BuildContext context, String uid) async {
    final historyCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('history');

    try {
      final snapshots = await historyCollection.get();

      // Batch delete for efficiency
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("History cleared successfully")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error clearing history: $e")),
        );
      }
    }
  }

  // Confirmation Dialog updated with your green application theme
  void _showDeleteDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear History", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete all your analysis records? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _clearHistory(context, uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700, // Matches your green app theme
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("History Section", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 28),
              tooltip: "Clear History",
              onPressed: () => _showDeleteDialog(context, user.uid),
            ),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off, size: 80, color: Colors.white54),
                      const SizedBox(height: 10),
                      Text("No history found", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;

                  // Extract fields matching your database structure
                  String cropName = data['crop'] ?? "Unknown Crop";

                  // Clean Fixed Section: Safely parse values into integers whether they are saved as numbers or text strings
                  int nValue = data['n'] is int
                      ? data['n']
                      : int.tryParse(data['n']?.toString() ?? '0') ?? 0;

                  int pValue = data['p'] is int
                      ? data['p']
                      : int.tryParse(data['p']?.toString() ?? '0') ?? 0;

                  int kValue = data['k'] is int
                      ? data['k']
                      : int.tryParse(data['k']?.toString() ?? '0') ?? 0;

                  DateTime date = data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now();
                  String formattedDate = DateFormat('yMMMd').add_jm().format(date);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: const Color(0xFFF9F7FA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        // Requirements implemented: Redirects to ResultScreen with dataset parameter maps bound
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultScreen(
                                predictedCrop: cropName,
                                soilData: {
                                  "N": nValue.toString(),
                                  "P": pValue.toString(),
                                  "K": kValue.toString(),
                                  "pH": data['ph']?.toString() ?? "6.5",
                                  "Temp": "Historical",
                                  "Rain": "Historical",
                                },
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFC8E6C9),
                                child: const Icon(Icons.spa, color: Color(0xFF2E7D32)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cropName.toLowerCase(),
                                      style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Date: $formattedDate",
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "N: $nValue | P: $pValue | K: $kValue",
                                      style: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}