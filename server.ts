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

interface ParsedScoringComponent {
  field: string;
  label: string;
  maxPoints: number;
}

interface ParsedStrategySpec {
  id: number;
  enumKey: string;
  name: string;
  module: string;
  suitableRegimes: string[];
  conditionalRegimes: string[];
  defaults: Array<{ key: string; value: string }>;
  hasCustomExit: boolean;
}

interface ParsedCsvSchema {
  index: number;
  filename: string;
  columns: string[];
}

interface ParsedPresetSpec {
  path: string;
  assetGroup: string;
  name: string;
  configLabel: string;
  operatingMode: string;
  allowLiveTrading: boolean;
  riskPct: string;
  minScore: string;
  maxSpread: string;
  multiSymbolList: string;
}

interface SubsystemSummary {
  category: string;
  fileCount: number;
  totalLines: number;
  files: string[];
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

    const inputMatch = line.match(
      /^input\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)\s*=\s*([^;]+);\s*(?:\/\/\s*(.*))?$/,
    );
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

function formatFieldLabel(field: string): string {
  return field
    .replace(/Score$/, '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/^./, (c) => c.toUpperCase())
    .trim();
}

function parseTypesMqh(source: string) {
  const nameMatch = source.match(/#define\s+EA_PROJECT_NAME\s+"([^"]+)"/);
  const versionMatch = source.match(/#define\s+EA_PROJECT_VERSION\s+"([^"]+)"/);
  const maxRegimesMatch = source.match(/#define\s+EA_MAX_REGIMES\s+(\d+)/);
  const maxSymbolsMatch = source.match(/#define\s+EA_MAX_SYMBOLS\s+(\d+)/);
  const maxStrategiesMatch = source.match(/#define\s+EA_MAX_STRATEGIES\s+(\d+)/);

  const regimeLabelMap = new Map<string, string>();
  const regFnMatch = source.match(/string\s+RegimeToString[\s\S]*?\{([\s\S]*?)\n\}/);
  if (regFnMatch) {
    const caseRegex = /case\s+(REGIME_[A-Z0-9_]+)\s*:\s*return\s+"([^"]+)"/g;
    let m: RegExpExecArray | null;
    while ((m = caseRegex.exec(regFnMatch[1])) !== null) {
      regimeLabelMap.set(m[1], m[2]);
    }
  }

  const stratEnumOrder = new Map<string, number>();
  const stratEnumMatch = source.match(/enum\s+ENUM_STRATEGY_ID\s*\{([\s\S]*?)\}/);
  if (stratEnumMatch) {
    const itemRegex = /(STRAT_[A-Z0-9_]+)\s*=\s*(\d+)/g;
    let m: RegExpExecArray | null;
    while ((m = itemRegex.exec(stratEnumMatch[1])) !== null) {
      stratEnumOrder.set(m[1], Number(m[2]));
    }
  }

  const opModes = new Map<string, string>();
  const opEnumMatch = source.match(/enum\s+ENUM_EA_OPERATING_MODE\s*\{([\s\S]*?)\}/);
  if (opEnumMatch) {
    const itemRegex = /(EA_MODE_[A-Z0-9_]+)\s*=\s*(\d+)/g;
    let m: RegExpExecArray | null;
    while ((m = itemRegex.exec(opEnumMatch[1])) !== null) {
      opModes.set(m[2], m[1]);
    }
  }

  const scoringComponents: ParsedScoringComponent[] = [];
  const scoreStructMatch = source.match(/struct\s+SScoreBreakdown\s*\{([\s\S]*?)\n\};/);
  if (scoreStructMatch) {
    const lines = scoreStructMatch[1].split(/\r?\n/);
    for (const line of lines) {
      const m = line.match(/double\s+([A-Za-z0-9_]+)\s*;\s*\/\/\s*0\.\.(\d+)/);
      if (m && m[1] !== 'totalScore') {
        scoringComponents.push({
          field: m[1],
          label: formatFieldLabel(m[1]),
          maxPoints: Number(m[2]),
        });
      }
    }
  }

  return {
    eaName: nameMatch?.[1] ?? 'AdvancedScalpingEA',
    version: versionMatch?.[1] ?? '0.0.0',
    maxRegimes: maxRegimesMatch ? Number(maxRegimesMatch[1]) : regimeLabelMap.size,
    maxSymbols: maxSymbolsMatch ? Number(maxSymbolsMatch[1]) : 1,
    maxStrategies: maxStrategiesMatch ? Number(maxStrategiesMatch[1]) : 0,
    regimeLabelMap,
    stratEnumOrder,
    opModes,
    scoringComponents,
  };
}

async function parseStrategiesFromDir(
  stratDir: string,
  regimeLabelMap: Map<string, string>,
  stratEnumOrder: Map<string, number>,
): Promise<ParsedStrategySpec[]> {
  const entries = await fs.readdir(stratDir, { withFileTypes: true });
  const specs: ParsedStrategySpec[] = [];

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.mqh') || entry.name === 'StrategyBase.mqh') {
      continue;
    }
    const content = await fs.readFile(path.join(stratDir, entry.name), 'utf-8');
    const ctorMatch = content.match(
      /:\s*CStrategyBase\(\s*(STRAT_[A-Z0-9_]+)\s*,\s*"([^"]+)"\s*\)\s*\{([\s\S]*?)\n\s*\}/,
    );
    const enumKey = ctorMatch?.[1] ?? '';
    const name = ctorMatch?.[2] ?? entry.name.replace('.mqh', '');
    const ctorBody = ctorMatch?.[3] ?? '';

    const defaults: Array<{ key: string; value: string }> = [];
    const assignRegex = /^\s*(m_[A-Za-z0-9_]+)\s*=\s*([^;]+);/gm;
    let am: RegExpExecArray | null;
    while ((am = assignRegex.exec(ctorBody)) !== null) {
      defaults.push({ key: am[1].replace(/^m_/, ''), value: am[2].trim() });
    }

    const suitableRegimes: string[] = [];
    const conditionalRegimes: string[] = [];
    const suitFnMatch = content.match(/GetRegimeSuitability\([^)]*\)[^{]*\{([\s\S]*?)\n\s*\}/);
    if (suitFnMatch) {
      const stmtRegex = /if\s*\(([\s\S]*?)\)\s*(?:\{\s*)?return\s+(SUIT_[A-Z_]+)\s*;/g;
      let sm: RegExpExecArray | null;
      while ((sm = stmtRegex.exec(suitFnMatch[1])) !== null) {
        const condChunk = sm[1];
        const tag = sm[2];
        const regMatches = condChunk.match(/REGIME_[A-Z0-9_]+/g) ?? [];
        for (const r of regMatches) {
          const readable = regimeLabelMap.get(r) ?? r;
          if (tag === 'SUIT_SUITABLE' && !suitableRegimes.includes(readable)) {
            suitableRegimes.push(readable);
          } else if (tag === 'SUIT_CONDITIONAL' && !conditionalRegimes.includes(readable)) {
            conditionalRegimes.push(readable);
          }
        }
      }
    }

    specs.push({
      id: (stratEnumOrder.get(enumKey) ?? specs.length) + 1,
      enumKey,
      name,
      module: entry.name,
      suitableRegimes,
      conditionalRegimes,
      defaults,
      hasCustomExit: /ShouldExitPosition\s*\(/.test(content),
    });
  }

  return specs.sort((a, b) => a.id - b.id);
}

function parseCsvSchemas(source: string): ParsedCsvSchema[] {
  const schemas: ParsedCsvSchema[] = [];
  const fnRegex = /m_fileNames\[(\d+)\]\s*=\s*"([^"]+)";[\s\S]*?m_headers\[\1\]\s*=\s*"([^"]+)";/g;
  let m: RegExpExecArray | null;
  while ((m = fnRegex.exec(source)) !== null) {
    schemas.push({
      index: Number(m[1]),
      filename: m[2],
      columns: m[3].split(',').map((c) => c.trim()),
    });
  }
  return schemas.sort((a, b) => a.index - b.index);
}

async function parsePresetsFromFiles(
  files: ProjectFileEntry[],
  opModes: Map<string, string>,
): Promise<ParsedPresetSpec[]> {
  const presetFiles = files.filter((f) => f.ext === '.set');
  const presets: ParsedPresetSpec[] = [];

  for (const f of presetFiles) {
    const content = await fs.readFile(path.join(EA_ROOT, f.path), 'utf-8');
    const kv = new Map<string, string>();
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith(';')) continue;
      const eq = trimmed.indexOf('=');
      if (eq > 0) {
        kv.set(trimmed.slice(0, eq).trim(), trimmed.slice(eq + 1).trim());
      }
    }
    const rawMode = kv.get('InpOperatingMode') ?? '0';
    const parts = f.path.split('/');
    presets.push({
      path: f.path,
      assetGroup: parts.length > 2 ? parts[1] : 'General',
      name: f.name.replace('.set', ''),
      configLabel: kv.get('InpConfigLabel') ?? f.name,
      operatingMode: opModes.get(rawMode) ?? rawMode,
      allowLiveTrading: kv.get('InpAllowLiveTrading') === 'true',
      riskPct: kv.get('InpRiskPerTradePct') ?? '—',
      minScore: kv.get('InpMinSignalScore') ?? '—',
      maxSpread: kv.get('InpMaxSpreadPoints') ?? '—',
      multiSymbolList: kv.get('InpMultiSymbolList') ?? '',
    });
  }
  return presets;
}

function buildSubsystems(files: ProjectFileEntry[]): SubsystemSummary[] {
  const map = new Map<string, { totalLines: number; files: string[] }>();
  for (const f of files) {
    const cur = map.get(f.category) ?? { totalLines: 0, files: [] };
    cur.totalLines += f.lines;
    cur.files.push(f.name);
    map.set(f.category, cur);
  }
  return Array.from(map.entries())
    .map(([category, info]) => ({
      category,
      fileCount: info.files.length,
      totalLines: info.totalLines,
      files: info.files,
    }))
    .sort((a, b) => a.category.localeCompare(b.category));
}

async function startServer() {
  const app = express();

  app.get('/api/project/tree', async (_req, res) => {
    try {
      const files = await collectFiles(EA_ROOT);
      res.json({ root: 'AdvancedScalpingEA', files });
    } catch {
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
      const [mq5Content, typesContent, csvLoggerContent] = await Promise.all([
        fs.readFile(path.join(EA_ROOT, 'Experts', 'AdvancedScalpingEA.mq5'), 'utf-8'),
        fs.readFile(path.join(EA_ROOT, 'Include', 'Core', 'Types.mqh'), 'utf-8'),
        fs.readFile(path.join(EA_ROOT, 'Include', 'Analytics', 'CSVLogger.mqh'), 'utf-8'),
      ]);

      const inputs = parseInputsFromMq5(mq5Content);
      const typesMeta = parseTypesMqh(typesContent);
      const strategies = await parseStrategiesFromDir(
        path.join(EA_ROOT, 'Include', 'Strategies'),
        typesMeta.regimeLabelMap,
        typesMeta.stratEnumOrder,
      );
      const csvSchemas = parseCsvSchemas(csvLoggerContent);
      const presets = await parsePresetsFromFiles(files, typesMeta.opModes);
      const subsystems = buildSubsystems(files);

      const inputMap = new Map(inputs.map((i) => [i.name, i.defaultValue]));
      const defaultMode = inputMap.get('InpOperatingMode') ?? 'EA_MODE_LIVE_TRADING';
      const allowLiveTrading = inputMap.get('InpAllowLiveTrading') === 'true';
      const confirmLiveRiskAck = inputMap.get('InpConfirmLiveRiskAcknowledgement') === 'true';
      const defaultMinScore = Number(inputMap.get('InpMinSignalScore') ?? 0);
      const inputGroups = Array.from(new Set(inputs.map((i) => i.group)));

      const totalLines = files.reduce((acc, f) => acc + f.lines, 0);
      const mqlCount = files.filter((f) => f.ext === '.mq5' || f.ext === '.mqh').length;
      const mq5Count = files.filter((f) => f.ext === '.mq5').length;
      const mqhCount = files.filter((f) => f.ext === '.mqh').length;
      const presetCount = files.filter((f) => f.ext === '.set').length;

      res.json({
        eaName: typesMeta.eaName,
        version: typesMeta.version,
        defaultMode,
        allowLiveTrading,
        confirmLiveRiskAck,
        liveTradingDefault: defaultMode === 'EA_MODE_LIVE_TRADING' && allowLiveTrading && confirmLiveRiskAck,
        defaultMinScore,
        maxRegimes: typesMeta.maxRegimes,
        maxSymbols: typesMeta.maxSymbols,
        fileCount: files.length,
        mqlCount,
        mq5Count,
        mqhCount,
        presetCount,
        totalLines,
        inputCount: inputs.length,
        inputGroups,
        inputs,
        strategies,
        scoringComponents: typesMeta.scoringComponents,
        csvSchemas,
        presets,
        subsystems,
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
