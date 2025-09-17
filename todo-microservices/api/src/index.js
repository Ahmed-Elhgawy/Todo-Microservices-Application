require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const amqplib = require('amqplib');
const pool = require('./db');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const PORT = process.env.PORT;
const RABBIT_URL = process.env.RABBIT_URL;

let channel = null;
async function initRabbit() {
  const conn = await amqplib.connect(RABBIT_URL);
  channel = await conn.createChannel();
  await channel.assertExchange('todos', 'topic', { durable: true });
  console.log('Connected to RabbitMQ');
}

app.get('/health', (req, res) => res.json({ ok: true }));

// CRUD endpoints
app.get('/todos', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM todos ORDER BY created_at DESC');
  res.json(rows);
});

app.get('/todos/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
});

app.post('/todos', async (req, res) => {
  const { title, description } = req.body;
  const [result] = await pool.query('INSERT INTO todos (title, description) VALUES (?, ?)', [title, description]);
  const todoId = result.insertId;
  const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [todoId]);
  const todo = rows[0];

  // publish event
  const payload = { event: 'todo.created', data: todo };
  channel.publish('todos', 'todo.created', Buffer.from(JSON.stringify(payload)), { persistent: true });

  res.status(201).json(todo);
});

app.put('/todos/:id', async (req, res) => {
  const { title, description, done } = req.body;
  await pool.query('UPDATE todos SET title = ?, description = ?, done = ? WHERE id = ?', [title, description, !!done, req.params.id]);
  const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [req.params.id]);
  const todo = rows[0];
  const payload = { event: 'todo.updated', data: todo };
  channel.publish('todos', 'todo.updated', Buffer.from(JSON.stringify(payload)), { persistent: true });
  res.json(todo);
});

app.delete('/todos/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Not found' });
  await pool.query('DELETE FROM todos WHERE id = ?', [req.params.id]);
  const payload = { event: 'todo.deleted', data: { id: req.params.id } };
  channel.publish('todos', 'todo.deleted', Buffer.from(JSON.stringify(payload)), { persistent: true });
  res.json({ success: true });
});

app.listen(PORT, async () => {
  console.log(`API listening on ${PORT}`);
  // init rabbit and ensure db is reachable
  try {
    await initRabbit();
    console.log('API ready');
  } catch (err) {
    console.error('Error initializing services', err);
    process.exit(1);
  }
});
