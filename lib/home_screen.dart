import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crop_form_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'feedback_screen.dart'; // 🌟 Imported your dedicated feedback screen file

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Re-added the confirmation dialog logic with updated green application theme
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700), // Updated to dark accent green
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            var userData = snapshot.data?.data() as Map<String, dynamic>?;
            String fullName = userData?['fullName'] ?? "Farmer";

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $fullName",
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildMenuCard(
                    title: "Get Crop Recommendation",
                    subtitle: "Analyze soil for best results",
                    icon: Icons.eco_outlined,
                    iconColor: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CropFormScreen())),
                  ),
                  _buildMenuCard(
                    title: "Profile",
                    subtitle: "Edit account and preferences",
                    icon: Icons.person_outline,
                    iconColor: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                  ),
                  _buildMenuCard(
                    title: "History",
                    subtitle: "View previous analysis",
                    icon: Icons.history,
                    iconColor: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                  ),

                  // 🌟 New Feedback Option navigating straight to your custom Feedback Screen
                  _buildMenuCard(
                    title: "Feedback",
                    subtitle: "Share thoughts and view past posts",
                    icon: Icons.feedback_outlined,
                    iconColor: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackScreen())),
                  ),

                  _buildMenuCard(
                    title: "About App",
                    subtitle: "Version, Purpose & Developers",
                    icon: Icons.info_outline,
                    iconColor: Colors.purple,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "FARM",
                        applicationVersion: "1.0.0",
                        applicationIcon: const Icon(Icons.eco, color: Colors.green, size: 40),
                        children: [
                          const Text("Sustainable Precision Farming Powered by AI "
                              "(IKM-Products)"),
                        ],
                      );
                    },
                  ),
                  _buildMenuCard(
                    title: "Logout",
                    subtitle: "Sign out of your account",
                    icon: Icons.logout,
                    iconColor: Colors.green.shade700, // Updated to dark accent green
                    isLogout: true, // Mark this to trigger theme integrated dark green text
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: isLogout ? Colors.green.shade700 : Colors.black87 // Updated theme-integrated green text for Logout
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
      ),
    );
  }
}