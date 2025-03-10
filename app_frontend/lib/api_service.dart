import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3000'; // Backend URL
  final String omdbApiKey = '71dbba92'; // Replace with your actual API key
  final String omdbUrl = 'http://www.omdbapi.com/';
  final FlutterSecureStorage storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> getMovieDetails(String movieName) async {
    try {
      final response = await http.get(
        Uri.parse('$omdbUrl?t=$movieName&apikey=$omdbApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'True') {
          return data; // Contains movie details like Title, Poster, Year, etc.
        } else {
          throw Exception('Movie not found');
        }
      } else {
        throw Exception('Failed to load movie details');
      }
    } catch (e) {
      throw Exception('Error fetching movie details: $e');
    }
  }

  Future<void> addMovie(Map<String, dynamic> movieData) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception('Token not found. Please log in.');

      final response = await http.post(
        Uri.parse('$baseUrl/movies'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(movieData),
      );

      print('Request Body: ${json.encode(movieData)}');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode != 201) {
        throw Exception('Failed to add movie to database: ${response.body}');
      }
    } catch (e) {
      print('Error while adding movie: $e');
      throw e;
    }
  }

  Future<List<dynamic>> getMovieRatings(String movieId) async {
    final token = await storage.read(key: 'token');
    if (token == null) throw Exception('Token not found. Please log in.');

    final response = await http.get(
      Uri.parse('$baseUrl/movies/$movieId/ratings'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Parsed ratings
    } else {
      throw Exception('Failed to fetch ratings: ${response.body}');
    }
  }

  Future<void> addRating(String movieId, int rating) async {
    String body = '';
    try {
      final token = await storage.read(key: 'token');
      if (token == null) {
        throw Exception('Token not found. Please log in.');
      }

      body = json.encode({'movie_id': movieId, 'rating': rating});
      final response = await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 201) {
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        throw Exception('Failed to add rating');
      }
    } catch (e) {
      print('Request Body: $body');
      print('Error: $e');
      throw Exception('Error adding rating: $e');
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Failed to register: ${json.decode(response.body)['error']}');
      }
    } catch (e) {
      throw Exception('Error during registration: $e');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await storage.write(
            key: 'token', value: data['token']); // Save the token securely
      } else {
        throw Exception(
            'Failed to login: ${json.decode(response.body)['error']}');
      }
    } catch (e) {
      throw Exception('Error during login: $e');
    }
  }
}
