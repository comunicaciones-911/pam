// Simulador mínimo de Apps Script + Google Sheets para probar Code.gs
const fs = require('fs'), http = require('http'), crypto = require('crypto'), vm = require('vm');
const CODE = process.argv[2], PORT = +process.argv[3] || 8790, DUMP = process.argv[4] || '/tmp/gas-sheet.json';

class Sheet {
  constructor(name) { this.name = name; this.data = []; this.maxCols = 26; this.maxRows = 1000; this.frozen = 0; this.notes = {}; }
  getName() { return this.name; }
  getLastRow() { let n = this.data.length; while (n > 0 && (this.data[n - 1] || []).every(v => v === '' || v == null)) n--; return n; }
  getMaxColumns() { return this.maxCols; } getMaxRows() { return this.maxRows; }
  insertColumnsAfter(a, n) { this.maxCols += n; }
  getRange(r, c, nr = 1, nc = 1) { return new Range(this, r, c, nr, nc); }
  setFrozenRows(n) { this.frozen = n; } setColumnWidth() {} hideColumns() {}
  deleteRow(r) { this.data.splice(r - 1, 1); }
  appendRow(v) { this.data[this.getLastRow()] = v.slice(); }
}
class Range {
  constructor(s, r, c, nr, nc) { Object.assign(this, { s, r, c, nr, nc }); }
  getValues() { const o = []; for (let i = 0; i < this.nr; i++) { const row = this.s.data[this.r - 1 + i] || []; o.push(Array.from({ length: this.nc }, (_, j) => row[this.c - 1 + j] ?? '')); } return o; }
  getDisplayValues() { return this.getValues().map(r => r.map(String)); }
  setValues(v) { v.forEach((row, i) => { const idx = this.r - 1 + i; this.s.data[idx] ||= []; row.forEach((x, j) => { this.s.data[idx][this.c - 1 + j] = x; }); }); return this; }
  setValue(x) { return this.setValues([[x]]); }
  setNumberFormat() { return this; } setFontWeight() { return this; } setFontColor() { return this; } setBackground() { return this; }
  setNote(n) { this.s.notes[this.r + ',' + this.c] = n; return this; }
}
const book = { sheets: [new Sheet('Hoja 1')] };
const SS = {
  getSheetByName: n => book.sheets.find(s => s.name === n) || null,
  insertSheet: n => { const s = new Sheet(n); book.sheets.push(s); return s; },
  getSheets: () => book.sheets, deleteSheet: s => { book.sheets = book.sheets.filter(x => x !== s); }, setActiveSheet() {}
};
const cache = {};
const ctx = {
  SpreadsheetApp: { getActive: () => SS, flush() {} },
  ContentService: { MimeType: { JSON: 'json' }, createTextOutput: t => ({ t, setMimeType() { return this; } }) },
  CacheService: { getScriptCache: () => ({ put: (k, v) => { cache[k] = v; }, get: k => cache[k] ?? null }) },
  LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
  DriveApp: { Access: {}, Permission: {}, createFolder: () => ({ getId: () => 'FOLDER1', createFile: () => ({ getId: () => 'IMG' + Date.now(), setSharing() {} }) }), getFolderById: () => ({ createFile: () => ({ getId: () => 'IMG' + Date.now(), setSharing() {} }) }) },
  Utilities: {
    DigestAlgorithm: { SHA_256: 'sha256' }, Charset: { UTF_8: 'utf8' },
    computeDigest: (a, t) => [...crypto.createHash('sha256').update(t, 'utf8').digest()].map(b => b > 127 ? b - 256 : b),
    getUuid: () => crypto.randomUUID(), base64Decode: s => Buffer.from(s, 'base64'), newBlob: () => ({}),
    formatDate: (d, tz, f) => { const x = new Date(d.getTime() - 4 * 3600e3), p = n => String(n).padStart(2, '0');
      return f.replace('yyyy', x.getUTCFullYear()).replace('yy', String(x.getUTCFullYear()).slice(2)).replace('MM', p(x.getUTCMonth() + 1)).replace('dd', p(x.getUTCDate())).replace('HH', p(x.getUTCHours())).replace('mm', p(x.getUTCMinutes())); }
  },
  console
};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(CODE, 'utf8'), ctx);
console.log('configurar:', ctx.configurar());
const dump = () => fs.writeFileSync(DUMP, JSON.stringify(Object.fromEntries(book.sheets.map(s => [s.name, s.data])), null, 1));
dump();
http.createServer((req, res) => {
  let body = ''; req.on('data', c => body += c); req.on('end', () => {
    const u = new URL(req.url, 'http://x');
    let out;
    if (req.method === 'POST') out = ctx.doPost({ postData: { contents: body } });
    else out = ctx.doGet({ parameter: Object.fromEntries(u.searchParams) });
    dump();
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }); res.end(out.t);
  });
}).listen(PORT, () => console.log('mock on', PORT));
