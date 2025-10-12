import 'package:flutter/material.dart';

/// Página inicial (Home) do aplicativo
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Home',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF9AA0A6),
          ),
        ),
      ),
    );
  }
}

