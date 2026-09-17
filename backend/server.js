const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');
const cors = require('cors'); // Add this line
const fs = require('fs');
const path = require('path');

const app = express();
const port = 3000;

// Middleware to enable CORS
app.use(cors()); // Add this line

app.use(bodyParser.json());

// MySQL database connection
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'calc_app_db',
  port: process.env.DB_PORT || 3306,
  connectionLimit: process.env.DB_CONNECTION_LIMIT || 10,
  // mysql2 has no "Amazon RDS" shorthand like the old mysql package - the
  // actual CA bundle has to be supplied for the handshake to validate.
  ssl: {
    ca: fs.readFileSync(path.join(__dirname, 'certs', 'rds-ca-bundle.pem')),
  },
});

// Test the MySQL connection - skipped when this file is require()'d
// (e.g. by tests) rather than run directly, so importing server.js for
// testing doesn't need a real database or crash the process on connect
// failure via process.exit(1).
if (require.main === module) {
  pool.getConnection((err, connection) => {
    if (err) {
      // Log the error to server.log
      console.error(`[${new Date().toISOString()}] Error connecting to MySQL: ${err.message}`);
      console.error('Error connecting to MySQL:', err);
      process.exit(1); // Exit the process with an error code
    } else {
      console.log('Connected to MySQL database');
      connection.query("SHOW STATUS LIKE 'Ssl_cipher'", (sslErr, rows) => {
        if (!sslErr && rows[0]) {
          console.log(`MySQL connection SSL cipher: ${rows[0].Value || '(none - not using TLS)'}`);
        }
        connection.release(); // Release the connection back to the pool
      });
    }
  });
}

// Registration endpoint
app.post('/calculator/api/register', async (req, res) => {
    const { username, password } = req.body;
    
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        pool.query(
            'INSERT INTO users (username, password) VALUES (?, ?)',
            [username, hashedPassword],
            (error, results) => {
                if (error) {
                    console.error('Database error:', error);
                    return res.status(500).json({ error: 'Database error' });
                }
                res.status(201).json({ message: 'User registered successfully!' });
            }
        );
    } catch (error) {
        console.error('Registration failed:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Login endpoint
app.post('/calculator/api/login', (req, res) => {
    const { username, password } = req.body;

    pool.query(
        'SELECT * FROM users WHERE username = ?',
        [username],
        async (error, results) => {
            if (error || results.length === 0) {
                console.error('Invalid credentials:', error);
                return res.status(401).json({ error: 'Invalid credentials' });
            }
            const user = results[0];
            try {
                const match = await bcrypt.compare(password, user.password);
                if (!match) {
                    return res.status(401).json({ error: 'Invalid credentials' });
                }
                const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: '1h' });
                res.json({ token });
            } catch (compareError) {
                console.error('Error comparing passwords:', compareError);
                res.status(500).json({ error: 'Login failed' });
            }
        }
    );
});

// Backend Server Endpoint Health Check for AWS ALB:
app.get('/backend', (req, res) => {
    res.status(200).send('OK');
  });

// Server Listens for response on port 3000 - same require.main guard as
// the MySQL check above: a test importing `app` shouldn't also bind a
// real port.
if (require.main === module) {
  app.listen(port, () => {
      console.log(`Server running on port ${port}`);
  });
}

module.exports = app;
