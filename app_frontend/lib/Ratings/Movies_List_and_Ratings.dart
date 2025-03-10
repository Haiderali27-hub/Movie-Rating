import 'package:app_frontend/api_service.dart';
import 'package:flutter/material.dart';

class MovieRatingsScreen extends StatefulWidget {
  final int? movieId; // Nullable for flexibility
  final String? movieName; // Nullable for flexibility

  const MovieRatingsScreen({super.key, this.movieId, this.movieName});

  @override
  _MovieRatingsScreenState createState() => _MovieRatingsScreenState();
}

class _MovieRatingsScreenState extends State<MovieRatingsScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController ratingController = TextEditingController();

  Map<String, dynamic>? movieDetails;
  List<dynamic> ratings = [];
  bool isLoading = false;

  // Search Movie Logic
  void searchMovie() async {
    if (searchController.text.isEmpty) {
      showErrorDialog('Please enter a movie name.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final details = await apiService.getMovieDetails(searchController.text);
      setState(() {
        movieDetails = {
          ...details,
          'IMDbRating': details['imdbRating'] ?? 'N/A',
          'RottenTomatoes': details['Ratings']?.firstWhere(
            (r) => r['Source'] == 'Rotten Tomatoes',
            orElse: () => {'Value': 'N/A'},
          )['Value'],
        };
      });

      // Fetch ratings from your backend
      final movieId = movieDetails!['imdbID'];
      final fetchedRatings = await apiService.getMovieRatings(movieId);
      setState(() {
        ratings = fetchedRatings;
      });
    } catch (e) {
      showErrorDialog('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Submit Rating Logic
  void submitRating() async {
    if (movieDetails == null) return;

    final rating = int.tryParse(ratingController.text);
    if (rating == null || rating < 1 || rating > 5) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content:
              Text('Invalid rating! Please enter a number between 1 and 5.'),
        ),
      );
      return;
    }

    try {
      final movieId = movieDetails!['imdbID'];

      // Add the movie to the database if it doesn't exist
      await apiService.addMovie({
        'id': movieId,
        'title': movieDetails!['Title'],
        'year': movieDetails!['Year'],
      });

      // Submit the rating
      await apiService.addRating(movieId, rating);

      // Fetch updated ratings
      final updatedRatings = await apiService.getMovieRatings(movieId);
      setState(() {
        ratings = updatedRatings;
      });
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('Error while adding rating: $e'),
        ),
      );
    }
  }

  // Show Error Dialog
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // UI Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movie Ratings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search movie by name...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: searchMovie,
                    child: Text('Search'),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Movie Details Section
              if (movieDetails != null)
                Column(
                  children: [
                    Image.network(
                      movieDetails!['Poster'] ??
                          'https://via.placeholder.com/150',
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image, size: 100);
                      },
                    ),
                    Text(
                      movieDetails!['Title'],
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text('Released: ${movieDetails!['Year']}'),
                    SizedBox(height: 8),
                    Text('IMDb Rating: ${movieDetails!['IMDbRating']}'),
                    Text('Rotten Tomatoes: ${movieDetails!['RottenTomatoes']}'),
                    SizedBox(height: 16),
                  ],
                ),

              // Rating Input Section
              TextField(
                controller: ratingController,
                decoration: InputDecoration(
                  labelText: 'Enter your rating (1-5)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: submitRating,
                child: Text('Submit Rating'),
              ),

              SizedBox(height: 16),

              // Ratings List Section
              if (!isLoading && ratings.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: ratings.length,
                  itemBuilder: (context, index) {
                    final rating = ratings[index];
                    return ListTile(
                      title: Text('User ${rating['user_id']}'),
                      subtitle: Text('Rating: ${rating['rating']}'),
                    );
                  },
                )
              else if (isLoading)
                Center(child: CircularProgressIndicator())
              else
                Center(child: Text('No ratings available')),
            ],
          ),
        ),
      ),
    );
  }
}
