require('dotenv').config(); // Load environment variables
const Joi = require('joi');

const express = require('express');
const cors = require('cors');
const mysql = require('mysql2');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const app = express();
const port = 3000;
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: { error: 'Too many requests, please try again later.' },
});

app.use(limiter); // Apply globally


const jwtSecret = process.env.JWT_SECRET || 'your-secret-key'; // Use environment variable for JWT secret
const registerSchema = Joi.object({
    name: Joi.string().min(3).required(),
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
});

const pagination = (req, res, next) => {
    req.limit = parseInt(req.query.limit) || 10;
    req.offset = parseInt(req.query.offset) || 0;
    next();
};

app.use(cors());
app.use(express.json());

const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Extract token after "Bearer"
    if (!token) return res.status(401).json({ error: 'Access Denied' });

    jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
        if (err) return res.status(403).json({ error: 'Invalid Token' });
        req.user = user;
        next();
    });
};


// MySQL Database Connection
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: process.env.DB_PASSWORD || 'nrhm..', // Use environment variable for password
    database: 'movie_rating_app',
});

db.connect(err => {
    if (err) {
        console.error('Database connection failed:', err);
        process.exit(1); // Exit if database connection fails
    } else {
        console.log('Connected to the database');
    }
});

// Routes

//LOGIN
app.post('/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
    }

    try {
        const query = 'SELECT * FROM users WHERE email = ?';
        const [results] = await db.promise().query(query, [email]);

        if (results.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = results[0];
        const validPassword = await bcrypt.compare(password, user.password);

        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const token = jwt.sign(
            { userId: user.id, email: user.email },
            jwtSecret,
            { expiresIn: '24h' }
        );

        res.status(200).json({
            token,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
            },
        });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});



//REGISTER
app.post('/register', async (req, res) => {
    const { error } = registerSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const { name, email, password } = req.body;

    try {
        const query = 'SELECT * FROM users WHERE email = ?';
        const [results] = await db.promise().query(query, [email]);

        if (results.length > 0) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const insertQuery = 'INSERT INTO users (name, email, password) VALUES (?, ?, ?)';
        await db.promise().query(insertQuery, [name, email, hashedPassword]);

        res.status(201).json({ message: 'User registered successfully' });
    } catch (err) {
        console.error('Error registering user:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});



//Ratings
app.post('/ratings', authenticateToken, async (req, res) => {
    const { movie_id, rating } = req.body;

    if (!movie_id || !rating) {
        return res.status(400).json({ error: 'movie_id and rating are required' });
    }

    try {
        // Check if the movie exists in the database
        const [movieResults] = await db.promise().query('SELECT id FROM movies WHERE id = ?', [movie_id]);

        if (movieResults.length === 0) {
            // Fetch movie details from OMDb API
            const axios = require('axios');
            const omdbResponse = await axios.get(`http://www.omdbapi.com/?i=${movie_id}&apikey=${process.env.OMDB_API_KEY}`);
            const movieData = omdbResponse.data;

            if (omdbResponse.data.Response === 'False') {
                return res.status(404).json({ error: 'Movie not found in OMDb API' });
            }

            // Add the movie to the database
            const insertMovieQuery = 'INSERT INTO movies (id, title, year) VALUES (?, ?, ?)';
            await db.promise().query(insertMovieQuery, [movie_id, movieData.Title, movieData.Year]);
        }

        // Add the rating
        const insertRatingQuery = 'INSERT INTO ratings (movie_id, user_id, rating) VALUES (?, ?, ?)';
        await db.promise().query(insertRatingQuery, [movie_id, req.user.userId, rating]);

        res.status(201).json({ message: 'Rating added successfully' });
    } catch (err) {
        console.error('Error adding rating:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});




app.post('/movies', authenticateToken, (req, res) => {
    const { id, title, year } = req.body;

    if (!id || !title || !year) {
        return res.status(400).json({ error: 'Missing movie details' });
    }

    const query = 'INSERT IGNORE INTO movies (id, title, year) VALUES (?, ?, ?)';
    db.query(query, [id, title, year], (err) => {
        if (err) {
            console.error('Error adding movie:', err);
            return res.status(500).json({ error: 'Internal server error' });
        }
        res.status(201).json({ message: 'Movie added successfully or already exists' });
    });
});

// Fetch ratings for a specific movie
app.get('/movies/:movieId/ratings', authenticateToken, (req, res) => {
    const { movieId } = req.params;
    const query = 'SELECT user_id, rating FROM ratings WHERE movie_id = ?';
    db.query(query, [movieId], (err, results) => {
        if (err) {
            console.error('Error fetching ratings:', err);
            return res.status(500).json({ error: 'Internal server error' });
        }
        res.status(200).json(results);
    });
});



//fetching details
app.get('/users/me', authenticateToken, (req, res) => {
    const query = 'SELECT id, name, email FROM users WHERE id = ?';
    db.query(query, [req.user.userId], (err, results) => {
        if (err) {
            console.error('Error fetching user info:', err);
            return res.status(500).json({ error: 'Internal server error' });
        }
        if (results.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.status(200).json(results[0]);
    });
});




// Start the server
app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
