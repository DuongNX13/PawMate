import fs from 'node:fs';
import path from 'node:path';

const utf8Decoder = new TextDecoder('utf-8', { fatal: true });

export function readUtf8(filePath) {
  const absolutePath = path.resolve(filePath);
  const bytes = fs.readFileSync(absolutePath);
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    throw new Error(`UTF-8 BOM is not allowed: ${absolutePath}`);
  }
  return { absolutePath, text: utf8Decoder.decode(bytes) };
}

export function parseCsv(text, sourceName = '<memory>') {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;

  const finishRow = () => {
    row.push(field);
    field = '';
    if (row.some((cell) => cell.length > 0)) rows.push(row);
    row = [];
  };

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];

    if (quoted) {
      if (char === '"') {
        if (text[index + 1] === '"') {
          field += '"';
          index += 1;
        } else {
          quoted = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      if (field.length !== 0) {
        throw new Error(`Unexpected quote in ${sourceName} at offset ${index}`);
      }
      quoted = true;
    } else if (char === ',') {
      row.push(field);
      field = '';
    } else if (char === '\n') {
      finishRow();
    } else if (char === '\r') {
      if (text[index + 1] === '\n') index += 1;
      finishRow();
    } else {
      field += char;
    }
  }

  if (quoted) throw new Error(`Unterminated quoted field in ${sourceName}`);
  if (field.length > 0 || row.length > 0) finishRow();
  if (rows.length === 0) throw new Error(`CSV has no header: ${sourceName}`);

  const headers = rows.shift().map((header) => header.trim());
  const duplicateHeaders = headers.filter(
    (header, index) => header.length === 0 || headers.indexOf(header) !== index,
  );
  if (duplicateHeaders.length > 0) {
    throw new Error(
      `CSV has blank or duplicate headers in ${sourceName}: ${[
        ...new Set(duplicateHeaders),
      ].join(', ')}`,
    );
  }

  const records = rows.map((cells, rowIndex) => {
    if (cells.length !== headers.length) {
      throw new Error(
        `CSV row ${rowIndex + 2} in ${sourceName} has ${cells.length} fields; expected ${headers.length}`,
      );
    }
    return Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
  });

  return { headers, records };
}

export function readCsv(filePath) {
  const { absolutePath, text } = readUtf8(filePath);
  return { absolutePath, ...parseCsv(text, absolutePath) };
}

export function requireHeaders(actualHeaders, requiredHeaders, errors) {
  for (const header of requiredHeaders) {
    if (!actualHeaders.includes(header)) errors.push(`Missing required header: ${header}`);
  }
}

export function clean(value) {
  return String(value ?? '').trim();
}

export function meaningful(value) {
  const normalized = clean(value);
  return normalized.length > 0 && normalized.toUpperCase() !== 'N/A';
}

export function printResult({ validator, file, records, errors, details = {} }) {
  const result = {
    validator,
    status: errors.length === 0 ? 'PASS' : 'FAIL',
    file,
    records,
    errors,
    ...details,
  };
  const target = errors.length === 0 ? console.log : console.error;
  target(JSON.stringify(result, null, 2));
  if (errors.length > 0) process.exitCode = 1;
}
