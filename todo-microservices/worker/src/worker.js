require('dotenv').config();
const amqplib = require('amqplib');
const mysql = require('mysql2/promise');

const RABBIT_URL = process.env.RABBIT_URL;

async function main() {
  const conn = await amqplib.connect(RABBIT_URL);
  const ch = await conn.createChannel();
  await ch.assertExchange('todos', 'topic', { durable: true });

  // create a dedicated queue for audits
  const q = await ch.assertQueue('todo_audit_queue', { durable: true });
  await ch.bindQueue(q.queue, 'todos', '#'); // consume all events

  const db = await mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5,
  });

  console.log('Worker waiting for messages...');
  ch.consume(q.queue, async (msg) => {
    if (!msg) return;
    try {
      const content = JSON.parse(msg.content.toString());
      const event_type = content.event || 'unknown';
      const payload = JSON.stringify(content.data || {});
      console.log('Worker received', event_type);

      // store audit row
      await db.query('INSERT INTO audit (event_type, payload) VALUES (?, ?)', [event_type, payload]);

      ch.ack(msg);
    } catch (err) {
      console.error('Worker error processing message', err);
      ch.nack(msg, false, false); // discard
    }
  }, { noAck: false });
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
