import express from 'express';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createServer as createViteServer } from 'vite';
import JSZip from 'jszip';

const PORT = 3000;
const PROJECT_ROOT = process.cwd();
const EA_ROOT = path.resolve(PROJECT_ROOT, 'AdvancedScalpingEA');

async function collectFiles(dir: string, relBase = ''): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const results: string[] = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = relBase ? `${relBase}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      const nested = await collectFiles(fullPath, relPath);
      results.push(...nested);
    } else if (entry.isFile()) {
      results.push(relPath);
    }
  }

  return results.sort();
}

async function startServer() {
  const app = express();

  app.get('/api/project/download-zip', async (_req, res) => {
    try {
      const files = await collectFiles(EA_ROOT);
      const zip = new JSZip();
      const folder = zip.folder('AdvancedScalpingEA');
      if (!folder) throw new Error('Zip folder init failed');

      for (const relPath of files) {
        const full = path.join(EA_ROOT, relPath);
        const content = await fs.readFile(full);
        folder.file(relPath, content);
      }

      const buffer = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
      res.setHeader('Content-Type', 'application/zip');
      res.setHeader('Content-Disposition', 'attachment; filename="AdvancedScalpingEA_MT5.zip"');
      res.send(buffer);
    } catch {
      res.status(500).json({ error: 'Failed to package MQL5 archive.' });
    }
  });

  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distDir = path.resolve(PROJECT_ROOT, 'dist');
    app.use(express.static(distDir));
    app.get('*', (_req, res) => {
      res.sendFile(path.join(distDir, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`ApexQuant MT5 Suite server listening on http://0.0.0.0:${PORT}`);
  });
}

startServer();
