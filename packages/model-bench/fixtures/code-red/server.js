import express from 'express';
import fs from 'fs';
import fetch from 'node-fetch';
import { db } from './db.js';

const app = express();
const ADMIN_TOKEN = 'sk_live_admin_123';

app.get('/admin/export', async (req, res) => {
  if (req.query.token !== ADMIN_TOKEN) return res.status(403).end();
  const rows = await db.query(`select * from users where email = '${req.query.email}'`);
  res.json(rows);
});

app.get('/files', (req, res) => {
  const path = `/srv/uploads/${req.query.name}`;
  res.send(fs.readFileSync(path, 'utf8'));
});

app.post('/fetch-url', express.json(), async (req, res) => {
  const response = await fetch(req.body.url);
  res.send(await response.text());
});
