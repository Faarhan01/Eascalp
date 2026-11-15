import { useEffect, useMemo, useState } from 'react';
import { Check, Copy, Download, FileCode2, Search } from 'lucide-react';
import type { ProjectFileEntry } from '../types/project';

interface CodeExplorerViewProps {
  files: ProjectFileEntry[];
}

export default function CodeExplorerView({ files }: CodeExplorerViewProps) {
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [selectedPath, setSelectedPath] = useState<string>('Experts/AdvancedScalpingEA.mq5');
  const [fileContent, setFileContent] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState<boolean>(false);

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const f of files) set.add(f.category);
    return ['ALL', ...Array.from(set).sort()];
  }, [files]);

  const filteredFiles = useMemo(() => {
    const q = search.trim().toLowerCase();
    return files.filter((f) => {
      if (categoryFilter !== 'ALL' && f.category !== categoryFilter) return false;
      if (!q) return true;
      return f.path.toLowerCase().includes(q) || f.name.toLowerCase().includes(q);
    });
  }, [files, search, categoryFilter]);

  useEffect(() => {
    if (!selectedPath && files.length > 0) {
      setSelectedPath(files[0].path);
    }
  }, [files, selectedPath]);

  useEffect(() => {
    if (!selectedPath) return;
    let active = true;
    setLoading(true);
    setError(null);

    fetch(`/api/project/file?path=${encodeURIComponent(selectedPath)}`)
      .then((res) => {
        if (!res.ok) throw new Error('Unable to load file');
        return res.json();
      })
      .then((data: { content: string }) => {
        if (active) {
          setFileContent(data.content);
          setLoading(false);
        }
      })
      .catch(() => {
        if (active) {
          setError('Failed to load MQL5 file content from workspace.');
          setLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [selectedPath]);

  const activeMeta = useMemo(
    () => files.find((f) => f.path === selectedPath) ?? null,
    [files, selectedPath],
  );

  const lines = useMemo(() => fileContent.split(/\r?\n/), [fileContent]);

  async function handleCopy() {
    if (!fileContent) return;
    await navigator.clipboard.writeText(fileContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }

  function handleDownloadSingle() {
    if (!fileContent || !activeMeta) return;
    const blob = new Blob([fileContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = activeMeta.name;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 border-b border-slate-800 pb-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-display text-xl font-semibold text-slate-100">
            MQL5 Source Code Explorer
          </h1>
          <p className="mt-1 text-xs text-slate-400">
            Inspect every native Expert Advisor header, strategy module, preset, and documentation file directly from disk.
          </p>
        </div>
        <div className="relative w-full sm:w-72">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-500" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Filter modules or filenames..."
            className="w-full rounded-lg border border-slate-800 bg-slate-900 py-2 pl-9 pr-3 text-xs text-slate-200 placeholder-slate-500 focus:border-sky-500 focus:outline-none"
          />
        </div>
      </div>

      {/* Category Filter Bar */}
      <div className="flex flex-wrap items-center gap-1.5">
        {categories.map((cat) => (
          <button
            key={cat}
            type="button"
            onClick={() => setCategoryFilter(cat)}
            className={`rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors whitespace-nowrap shrink-0 ${
              categoryFilter === cat
                ? 'bg-sky-600 text-white'
                : 'border border-slate-800 bg-slate-900 text-slate-400 hover:text-slate-200'
            }`}
          >
            {cat === 'ALL' ? `All Files (${files.length})` : cat}
          </button>
        ))}
      </div>

      {/* Split Explorer & Code Viewport */}
      <div className="grid gap-4 lg:grid-cols-[310px_1fr]">
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
          <div className="border-b border-slate-800 px-3.5 py-2.5 text-xs font-medium text-slate-400">
            Project Tree ({filteredFiles.length})
          </div>
          <div className="max-h-[640px] overflow-y-auto divide-y divide-slate-800/50">
            {filteredFiles.length === 0 ? (
              <p className="p-4 text-xs text-slate-500">No files match the active filter.</p>
            ) : (
              filteredFiles.map((file) => {
                const isActive = file.path === selectedPath;
                return (
                  <button
                    key={file.path}
                    type="button"
                    onClick={() => setSelectedPath(file.path)}
                    className={`w-full px-3.5 py-2.5 text-left transition-colors ${
                      isActive ? 'bg-sky-950/50 text-sky-300' : 'text-slate-300 hover:bg-slate-800/40'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="flex items-center gap-2 truncate font-mono text-xs">
                        <FileCode2 className="h-3.5 w-3.5 shrink-0 text-slate-500" />
                        <span className="truncate">{file.name}</span>
                      </span>
                      <span className="font-mono text-[11px] text-slate-500 tabular-nums shrink-0">
                        {file.lines}L
                      </span>
                    </div>
                    <p className="mt-0.5 truncate pl-5 text-[11px] text-slate-500">{file.path}</p>
                  </button>
                );
              })
            )}
          </div>
        </div>

        <div className="rounded-lg border border-slate-800 bg-[#080D1A] overflow-hidden flex flex-col">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-800 bg-slate-900/70 px-4 py-2.5">
            <div className="min-w-0">
              <p className="truncate font-mono text-xs font-medium text-slate-200">
                {selectedPath || 'Select a file'}
              </p>
              {activeMeta && (
                <p className="mt-0.5 text-[11px] text-slate-400 tabular-nums">
                  {activeMeta.lines} lines · {(activeMeta.sizeBytes / 1024).toFixed(1)} KB
                </p>
              )}
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                type="button"
                onClick={handleCopy}
                disabled={!fileContent}
                className="inline-flex items-center gap-1.5 rounded-md border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs font-medium text-slate-200 hover:bg-slate-800 disabled:opacity-50 whitespace-nowrap shrink-0"
              >
                {copied ? <Check className="h-3.5 w-3.5 text-emerald-400" /> : <Copy className="h-3.5 w-3.5" />}
                <span>{copied ? 'Copied' : 'Copy'}</span>
              </button>
              <button
                type="button"
                onClick={handleDownloadSingle}
                disabled={!fileContent}
                className="inline-flex items-center gap-1.5 rounded-md border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs font-medium text-slate-200 hover:bg-slate-800 disabled:opacity-50 whitespace-nowrap shrink-0"
              >
                <Download className="h-3.5 w-3.5" />
                <span>Download</span>
              </button>
            </div>
          </div>

          <div className="max-h-[640px] flex-1 overflow-auto p-3 font-mono text-xs leading-5">
            {loading ? (
              <div className="space-y-2 p-2">
                {Array.from({ length: 10 }).map((_, idx) => (
                  <div key={idx} className="h-4 w-full animate-pulse rounded bg-slate-800/60" />
                ))}
              </div>
            ) : error ? (
              <p className="p-4 text-xs text-red-400">{error}</p>
            ) : (
              <table className="w-full border-collapse">
                <tbody>
                  {lines.map((line, i) => (
                    <tr key={i} className="hover:bg-slate-900/60">
                      <td className="select-none pr-4 text-right text-slate-600 tabular-nums w-12 align-top">
                        {i + 1}
                      </td>
                      <td className="whitespace-pre text-slate-300">{line || ' '}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
