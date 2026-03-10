import 'package:access_app/presentation/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  static MaterialPageRoute<dynamic> route() {
    return MaterialPageRoute(builder: (context) => const DashboardPage());
  }

  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } finally {
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    LoginPage.route(),
                    (route) => false,
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      //Body
      body: const Center(child: Text('Welcome back.')),
    );
  }
}
