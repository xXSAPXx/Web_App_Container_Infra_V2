const request = require('supertest');
const app = require('./server');

// Both tests below deliberately avoid touching MySQL - server.js opens a
// real connection pool at module load, but neither of these routes'
// failure paths actually reaches pool.query(), so no database is needed
// to run these. See server.js's require.main guards for why importing
// `app` here doesn't also try to connect or bind a port.

describe('GET /backend', () => {
  it('responds 200 OK for the ALB health check', async () => {
    const res = await request(app).get('/backend');
    expect(res.status).toBe(200);
    expect(res.text).toBe('OK');
  });
});

describe('POST /calculator/api/register', () => {
  it('fails gracefully (500) instead of crashing when password is missing', async () => {
    const res = await request(app)
      .post('/calculator/api/register')
      .send({ username: 'testuser' }); // no password

    expect(res.status).toBe(500);
    expect(res.body).toHaveProperty('error');
  });
});
