import express from 'express';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createServer as createViteServer } from 'vite';
import JSZip from 'jszip';

const PORT = 3000;
const PROJECT_ROOT = process.cwd();
const EA_ROOT = path.resolve(PROJECT_ROOT, 'AdvancedScalpingEA');

interface ProjectFileEntry {
  path: string;
  name: string;
  category: string;
  ext: string;
  sizeBytes: number;
  lines: number;
}

interface ParsedInputParam {
  group: string;
  type: string;
  name: string;
  defaultValue: string;
  comment: string;
}

async function collectFiles(dir: string, relBase = ''): Promise<ProjectFileEntry[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const results: ProjectFileEntry[] = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = relBase ? `${relBase}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      const nested = await collectFiles(fullPath, relPath);
      results.push(...nested);
    } else if (entry.isFile()) {
      const stat = await fs.stat(fullPath);
      const content = await fs.readFile(fullPath, 'utf-8');
      const lines = content.split(/\r?\n/).length;
      const parts = relPath.split('/');
      const category = parts.length > 2 ? `${parts[0]}/${parts[1]}` : parts[0];
      results.push({
        path: relPath,
        name: entry.name,
        category,
        ext: path.extname(entry.name),
        sizeBytes: stat.size,
        lines,
      });
    }
  }

  return results.sort((a, b) => a.path.localeCompare(b.path));
}

function parseInputsFromMq5(source: string): ParsedInputParam[] {
  const lines = source.split(/\r?\n/);
  let currentGroup = 'General';
  const params: ParsedInputParam[] = [];

  for (const rawLine of lines) {
    const line = rawLine.trim();
    const groupMatch = line.match(/^input\s+group\s+"([^"]+)"/);
    if (groupMatch) {
      currentGroup = groupMatch[1].replace(/^=+\s*|\s*=+$/g, '').trim();
      continue;
    }

    const inputMatch = line.match(/^input\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)\s*=\s*([^;]+);\s*(?:\/\/\s*(.*))?$/);
    if (inputMatch) {
      params.push({
        group: currentGroup,
        type: inputMatch[1],
        name: inputMatch[2],
        defaultValue: inputMatch[3].trim(),
        comment: (inputMatch[4] ?? '').trim(),
      });
    }
  }
  return params;
}

async function startServer() {
  const app = express();

  app.get('/api/project/tree', async (_req, res) => {
    try {
      const files = await collectFiles(EA_ROOT);
      res.json({ root: 'AdvancedScalpingEA', files });
    } catch (err) {
      res.status(500).json({ error: 'Unable to enumerate AdvancedScalpingEA directory.' });
    }
  });

  app.get('/api/project/file', async (req, res) => {
    const rel = typeof req.query.path === 'string' ? req.query.path : '';
    if (!rel) {
      res.status(400).json({ error: 'Missing path parameter.' });
      return;
    }
    const target = path.resolve(EA_ROOT, rel);
    if (!target.startsWith(EA_ROOT + path.sep)) {
      res.status(403).json({ error: 'Forbidden path.' });
      return;
    }
    try {
      const content = await fs.readFile(target, 'utf-8');
      res.json({ path: rel, content });
    } catch {
      res.status(404).json({ error: 'File not found.' });
    }
  });

  app.get('/api/project/summary', async (_req, res) => {
    try {
      const files = await collectFiles(EA_ROOT);
      const mq5Path = path.join(EA_ROOT, 'Experts', 'AdvancedScalpingEA.mq5');
      const mq5Content = await fs.readFile(mq5Path, 'utf-8');
      const inputs = parseInputsFromMq5(mq5Content);
      const totalLines = files.reduce((acc, f) => acc + f.lines, 0);
      const mqlCount = files.filter((f) => f.ext === '.mq5' || f.ext === '.mqh').length;
      const presetCount = files.filter((f) => f.ext === '.set').length;
      res.json({
        eaName: 'AdvancedScalpingEA',
        version: '1.0.0',
        defaultMode: 'EA_MODE_RESEARCH_ONLY',
        liveTradingDefault: false,
        fileCount: files.length,
        mqlCount,
        presetCount,
        totalLines,
        inputCount: inputs.length,
        inputs,
      });
    } catch {
      res.status(500).json({ error: 'Failed to generate project summary.' });
    }
  });

  app.get('/api/project/download-zip', async (_req, res) => {
    try {
      const files = await collectFiles(EA_ROOT);
      const zip = new JSZip();
      const folder = zip.folder('AdvancedScalpingEA');
      if (!folder) throw new Error('Zip folder init failed');

      for (const f of files) {
        const full = path.join(EA_ROOT, f.path);
        const content = await fs.readFile(full);
        folder.file(f.path, content);
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
