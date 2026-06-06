import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _ProfileData {
  final String fullName;
  _ProfileData({required this.fullName});
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // Stream that fetches the current user's profile info from the 'users' collection
  Stream<_ProfileData> _userProfileStream() {
    if (_user == null) {
      return Stream.value(_ProfileData(fullName: "Farmer"));
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      final name = data?['fullName'] ?? "Farmer";
      return _ProfileData(fullName: name);
    });
  }

  // Submits a new feedback entry to Firestore using the user's full name
  Future<void> _submitFeedback(String currentUserName) async {
    if (_user == null) return;

    final messageText = _feedbackController.text.trim();
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Feedback message cannot be empty!")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': _user.uid,
        'userName': currentUserName, // Uses Name instead of email mapping layers
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _feedbackController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback submitted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit feedback: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Permanent document deletion logic rule mapping pipeline
  Future<void> _deleteFeedback(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('feedback').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback deleted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting feedback: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_ProfileData>(
      stream: _userProfileStream(),
      builder: (context, profileSnapshot) {
        final currentUserName = profileSnapshot.data?.fullName ?? "Farmer";

        return Scaffold(
          backgroundColor: const Color(0xFF4CAF50),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "Feedback Section",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            children: [
              // --- TOP CARD WORKSPACE: CREATING NEW FEEDBACKS ---
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Share your thoughts, $currentUserName",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Report bugs or suggest features here...",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : () => _submitFeedback(currentUserName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700, // 🌟 Updated button color to match dark accent green
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : Text(
                          "Submit Feedback",
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Your Previous Feedbacks",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- BOTTOM LAYER: REAL-TIME HISTORY QUERY DISPLAY ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feedback')
                      .where('userId', isEqualTo: _user?.uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "You haven't posted any feedback yet.",
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        String timeString = "Just now";
                        if (data['timestamp'] != null) {
                          final Timestamp t = data['timestamp'] as Timestamp;
                          timeString = DateFormat('yMMMd').add_jm().format(t.toDate());
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    data['userName'] ?? currentUserName,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade700),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteFeedback(doc.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(timeString, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                data['message'] ?? "",
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}