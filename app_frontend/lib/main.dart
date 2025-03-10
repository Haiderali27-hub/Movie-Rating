import 'package:app_frontend/Auth/login_screen.dart';
import 'package:app_frontend/Auth/registre_screen.dart';
import 'package:app_frontend/Ratings/Movies_List_and_Ratings.dart'; // Ensure the correct path
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/movies': (context) =>
            MovieRatingsScreen(), // Remove invalid parameters
      },
    );
  }
}
