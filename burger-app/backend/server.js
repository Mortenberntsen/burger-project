const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || 'database',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || 'passord123',
  database: process.env.DB_NAME || 'burgerhouse',
  port: 5432,
});

async function initDB(retries = 10) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS orders (
          id SERIAL PRIMARY KEY,
          customer_name VARCHAR(100),
          customer_phone VARCHAR(20),
          customer_address VARCHAR(200),
          items JSONB,
          total INTEGER,
          created_at TIMESTAMP DEFAULT NOW()
        )
      `);
      console.log('Database klar');
      return;
    } catch (e) {
      console.log(`Venter på database... (${i + 1}/${retries})`);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  throw new Error('Kunne ikke koble til database');
}

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

app.get('/api/orders', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 20');
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/orders/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM orders WHERE id = $1', [req.params.id]);
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/orders', async (req, res) => {
  const { customer_name, customer_phone, customer_address, items, total } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO orders (customer_name, customer_phone, customer_address, items, total) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [customer_name, customer_phone, customer_address, JSON.stringify(items), total]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const PORT = 3000;
app.listen(PORT, async () => {
  await initDB();
  console.log(`Backend kjører på port ${PORT}`);
});
