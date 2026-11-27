/* eslint-disable no-bitwise -- Binary container parsing requires exact bit masks and CRC32 operations. */
import { createHash } from 'node:crypto';

export const RESCUE_MEDIA_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
] as const;

export type RescueMediaMimeType = (typeof RESCUE_MEDIA_MIME_TYPES)[number];

export type RescueMediaSanitizationFailureReason =
  | 'empty_bytes'
  | 'unsupported_declared_mime'
  | 'unrecognized_magic'
  | 'mime_mismatch'
  | 'malformed_container';

export type RescueRemovedMetadata =
  | 'jpeg:APP1'
  | 'jpeg:APP13'
  | 'jpeg:COM'
  | 'png:eXIf'
  | 'png:tEXt'
  | 'png:zTXt'
  | 'png:iTXt'
  | 'png:tIME'
  | 'webp:EXIF'
  | 'webp:XMP'
  | 'webp:VP8X_EXIF_FLAG'
  | 'webp:VP8X_XMP_FLAG'
  | 'mp4:udta'
  | 'mp4:meta'
  | 'mp4:ilst'
  | 'mp4:uuid';

type RescueMediaSanitizationErrorContext = {
  declaredMimeType?: string;
  detectedMimeType?: RescueMediaMimeType;
};

export class RescueMediaSanitizationError extends Error {
  readonly reason: RescueMediaSanitizationFailureReason;

  readonly declaredMimeType?: string;

  readonly detectedMimeType?: RescueMediaMimeType;

  constructor(
    reason: RescueMediaSanitizationFailureReason,
    message: string,
    context: RescueMediaSanitizationErrorContext = {},
  ) {
    super(message);
    this.name = 'RescueMediaSanitizationError';
    this.reason = reason;
    this.declaredMimeType = context.declaredMimeType;
    this.detectedMimeType = context.detectedMimeType;
  }
}

export type SanitizeRescueMediaInput = {
  bytes: Buffer | Uint8Array;
  declaredMimeType: string;
};

export type SanitizeRescueMediaResult = {
  bytes: Buffer;
  originalSha256: string;
  originalSizeBytes: number;
  sanitizedSizeBytes: number;
  declaredMimeType: RescueMediaMimeType;
  detectedMimeType: RescueMediaMimeType;
  metadataRemoved: boolean;
  removedMetadata: RescueRemovedMetadata[];
};

type StripResult = {
  bytes: Buffer;
  removedMetadata: RescueRemovedMetadata[];
};

const PNG_SIGNATURE = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
]);

const JPEG_STANDALONE_MARKERS = new Set([
  0x01, 0xd8, 0xd9, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7,
]);

const JPEG_REMOVED_MARKERS = new Map<number, RescueRemovedMetadata>([
  [0xe1, 'jpeg:APP1'],
  [0xed, 'jpeg:APP13'],
  [0xfe, 'jpeg:COM'],
]);

const PNG_REMOVED_CHUNKS = new Map<string, RescueRemovedMetadata>([
  ['eXIf', 'png:eXIf'],
  ['tEXt', 'png:tEXt'],
  ['zTXt', 'png:zTXt'],
  ['iTXt', 'png:iTXt'],
  ['tIME', 'png:tIME'],
]);

const SUPPORTED_MIME_TYPES = new Set<string>(RESCUE_MEDIA_MIME_TYPES);

const malformed = (
  detectedMimeType: RescueMediaMimeType,
  message: string,
): never => {
  throw new RescueMediaSanitizationError('malformed_container', message, {
    detectedMimeType,
  });
};

const hasAsciiAt = (bytes: Buffer, offset: number, value: string) =>
  bytes.length >= offset + value.length &&
  bytes.subarray(offset, offset + value.length).toString('ascii') === value;

const isJpegSignature = (bytes: Buffer) =>
  bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xd8;

export const detectRescueMediaMimeType = (
  input: Buffer | Uint8Array,
): RescueMediaMimeType => {
  const bytes = Buffer.isBuffer(input) ? input : Buffer.from(input);
  if (bytes.length === 0) {
    throw new RescueMediaSanitizationError(
      'empty_bytes',
      'Media bytes must not be empty.',
    );
  }
  if (isJpegSignature(bytes)) {
    return 'image/jpeg';
  }
  if (
    bytes.length >= PNG_SIGNATURE.length &&
    bytes.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)
  ) {
    return 'image/png';
  }
  if (hasAsciiAt(bytes, 0, 'RIFF') && hasAsciiAt(bytes, 8, 'WEBP')) {
    return 'image/webp';
  }
  if (hasAsciiAt(bytes, 4, 'ftyp')) {
    return 'video/mp4';
  }
  throw new RescueMediaSanitizationError(
    'unrecognized_magic',
    'Media magic bytes are not recognized.',
  );
};

const validateJpegHeader = (bytes: Buffer) => {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) {
    return malformed('image/jpeg', 'JPEG is missing its SOI marker.');
  }
  return undefined;
};

const readJpegMarker = (bytes: Buffer, start: number) => {
  if (bytes[start] !== 0xff) {
    return malformed(
      'image/jpeg',
      'JPEG data outside a scan does not begin with a marker.',
    );
  }
  let offset = start;
  while (offset < bytes.length && bytes[offset] === 0xff) offset += 1;
  if (offset >= bytes.length)
    return malformed('image/jpeg', 'JPEG ends inside a marker prefix.');
  const marker = bytes[offset];
  if (marker === 0x00) {
    return malformed(
      'image/jpeg',
      'JPEG contains a stuffed marker byte outside entropy-coded data.',
    );
  }
  return { marker, offset: offset + 1 };
};

const jpegSegmentEnd = (bytes: Buffer, offset: number) => {
  if (offset + 2 > bytes.length)
    return malformed('image/jpeg', 'JPEG segment length is truncated.');
  const length = bytes.readUInt16BE(offset);
  if (length < 2 || offset + length > bytes.length)
    return malformed('image/jpeg', 'JPEG segment length is invalid.');
  return offset + length;
};

const jpegScanEnd = (bytes: Buffer, start: number) => {
  let offset = start;
  while (offset < bytes.length) {
    if (bytes[offset] !== 0xff) {
      offset += 1;
    } else {
      let markerCodeOffset = offset + 1;
      while (
        markerCodeOffset < bytes.length &&
        bytes[markerCodeOffset] === 0xff
      )
        markerCodeOffset += 1;
      if (markerCodeOffset >= bytes.length)
        return malformed(
          'image/jpeg',
          'JPEG entropy-coded data ends inside a marker.',
        );
      const marker = bytes[markerCodeOffset];
      if (marker === 0x00 || (marker >= 0xd0 && marker <= 0xd7))
        offset = markerCodeOffset + 1;
      else return offset;
    }
  }
  return malformed('image/jpeg', 'JPEG scan is missing an EOI marker.');
};

const stripJpegMetadata = (bytes: Buffer): StripResult => {
  validateJpegHeader(bytes);

  const parts: Buffer[] = [bytes.subarray(0, 2)];
  const removedMetadata: RescueRemovedMetadata[] = [];
  let offset = 2;
  let sawStartOfScan = false;
  let sawEndOfImage = false;

  while (offset < bytes.length) {
    const markerStart = offset;
    const next = readJpegMarker(bytes, offset);
    const { marker } = next;
    offset = next.offset;

    if (marker === 0xd9) {
      parts.push(bytes.subarray(markerStart, offset));
      sawEndOfImage = true;
      if (offset !== bytes.length) {
        return malformed(
          'image/jpeg',
          'JPEG contains trailing bytes after EOI.',
        );
      }
      break;
    }

    if (JPEG_STANDALONE_MARKERS.has(marker)) {
      parts.push(bytes.subarray(markerStart, offset));
    } else {
      const segmentEnd = jpegSegmentEnd(bytes, offset);
      const removedMarker = JPEG_REMOVED_MARKERS.get(marker);
      if (removedMarker) removedMetadata.push(removedMarker);
      else parts.push(bytes.subarray(markerStart, segmentEnd));
      offset = segmentEnd;

      if (marker === 0xda) {
        sawStartOfScan = true;
        const scanStart = offset;
        offset = jpegScanEnd(bytes, scanStart);
        parts.push(bytes.subarray(scanStart, offset));
      }
    }
  }

  if (!sawStartOfScan || !sawEndOfImage) {
    return malformed('image/jpeg', 'JPEG is missing SOS or EOI.');
  }
  return { bytes: Buffer.concat(parts), removedMetadata };
};

const CRC32_TABLE = Array.from({ length: 256 }, (_, tableIndex) => {
  let value = tableIndex;
  let bitIndex = 0;
  while (bitIndex < 8) {
    value = (value & 1) !== 0 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    bitIndex += 1;
  }
  return value >>> 0;
});

const crc32 = (bytes: Buffer) => {
  let crc = 0xffffffff;
  let index = 0;
  while (index < bytes.length) {
    crc = CRC32_TABLE[(crc ^ bytes[index]) & 0xff] ^ (crc >>> 8);
    index += 1;
  }
  return (crc ^ 0xffffffff) >>> 0;
};

const isPngChunkType = (bytes: Buffer) => {
  let index = 0;
  while (index < bytes.length) {
    const value = bytes[index];
    const isUppercase = value >= 0x41 && value <= 0x5a;
    const isLowercase = value >= 0x61 && value <= 0x7a;
    if (!isUppercase && !isLowercase) return false;
    index += 1;
  }
  return true;
};

const readPngChunk = (bytes: Buffer, offset: number) => {
  if (offset + 12 > bytes.length)
    return malformed('image/png', 'PNG chunk header is truncated.');
  const length = bytes.readUInt32BE(offset);
  if (length > 0x7fffffff)
    return malformed('image/png', 'PNG chunk length exceeds the format limit.');
  const typeOffset = offset + 4;
  const dataOffset = typeOffset + 4;
  const dataEnd = dataOffset + length;
  const end = dataEnd + 4;
  if (end > bytes.length)
    return malformed('image/png', 'PNG chunk payload is truncated.');
  const typeBytes = bytes.subarray(typeOffset, dataOffset);
  if (!isPngChunkType(typeBytes))
    return malformed('image/png', 'PNG chunk type contains invalid bytes.');
  const type = typeBytes.toString('ascii');
  if (
    bytes.readUInt32BE(dataEnd) !== crc32(bytes.subarray(typeOffset, dataEnd))
  ) {
    return malformed('image/png', `PNG ${type} chunk has an invalid CRC.`);
  }
  return { type, length, end };
};

type PngStructure = {
  sawHeader: boolean;
  sawImageData: boolean;
  sawEnd: boolean;
};
const validatePngHeader = (
  type: string,
  length: number,
  index: number,
  sawHeader: boolean,
) => {
  if (index === 0 && (type !== 'IHDR' || length !== 13)) {
    return malformed('image/png', 'PNG must start with a 13-byte IHDR chunk.');
  }
  if (type === 'IHDR' && (sawHeader || index !== 0)) {
    return malformed('image/png', 'PNG contains a misplaced IHDR chunk.');
  }
  return undefined;
};
const updatePngStructure = (
  state: PngStructure,
  type: string,
  length: number,
  index: number,
) => {
  validatePngHeader(type, length, index, state.sawHeader);
  const next = { ...state };
  if (type === 'IHDR') next.sawHeader = true;
  if (type === 'IDAT') next.sawImageData = true;
  if (type === 'IEND') {
    if (length !== 0 || state.sawEnd)
      return malformed('image/png', 'PNG IEND chunk is invalid.');
    next.sawEnd = true;
  }
  return next;
};

const stripPngMetadata = (bytes: Buffer): StripResult => {
  if (
    bytes.length < PNG_SIGNATURE.length ||
    !bytes.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)
  ) {
    return malformed('image/png', 'PNG signature is invalid.');
  }

  const parts: Buffer[] = [bytes.subarray(0, PNG_SIGNATURE.length)];
  const removedMetadata: RescueRemovedMetadata[] = [];
  let offset = PNG_SIGNATURE.length;
  let chunkIndex = 0;
  let state: PngStructure = {
    sawHeader: false,
    sawImageData: false,
    sawEnd: false,
  };

  while (offset < bytes.length) {
    const { type, length, end: chunkEnd } = readPngChunk(bytes, offset);
    state = updatePngStructure(state, type, length, chunkIndex);

    const removedChunk = PNG_REMOVED_CHUNKS.get(type);
    if (removedChunk) removedMetadata.push(removedChunk);
    else parts.push(bytes.subarray(offset, chunkEnd));

    offset = chunkEnd;
    chunkIndex += 1;
    if (state.sawEnd && offset !== bytes.length) {
      return malformed('image/png', 'PNG contains trailing bytes after IEND.');
    }
  }

  if (!state.sawHeader || !state.sawImageData || !state.sawEnd) {
    return malformed('image/png', 'PNG is missing IHDR, IDAT, or IEND.');
  }
  return { bytes: Buffer.concat(parts), removedMetadata };
};

const buildRiffChunk = (fourCc: string, payload: Buffer) => {
  const paddingLength = payload.length % 2;
  const chunk = Buffer.alloc(8 + payload.length + paddingLength);
  chunk.write(fourCc, 0, 4, 'ascii');
  chunk.writeUInt32LE(payload.length, 4);
  payload.copy(chunk, 8);
  return chunk;
};

const validateWebpHeader = (bytes: Buffer) => {
  if (
    bytes.length < 12 ||
    !hasAsciiAt(bytes, 0, 'RIFF') ||
    !hasAsciiAt(bytes, 8, 'WEBP')
  ) {
    return malformed('image/webp', 'WebP RIFF header is invalid.');
  }
  if (bytes.readUInt32LE(4) + 8 !== bytes.length) {
    return malformed('image/webp', 'WebP RIFF size does not match the bytes.');
  }
  return undefined;
};

const readWebpChunk = (bytes: Buffer, offset: number) => {
  if (offset + 8 > bytes.length)
    return malformed('image/webp', 'WebP chunk header is truncated.');
  const fourCc = bytes.subarray(offset, offset + 4).toString('ascii');
  const payloadLength = bytes.readUInt32LE(offset + 4);
  const payloadOffset = offset + 8;
  const payloadEnd = payloadOffset + payloadLength;
  const chunkEnd = payloadEnd + (payloadLength % 2);
  if (chunkEnd > bytes.length)
    return malformed('image/webp', `WebP ${fourCc} chunk is truncated.`);
  return { fourCc, payloadLength, payloadOffset, payloadEnd, chunkEnd };
};

const sanitizeWebpExtendedPayload = (
  payload: Buffer,
  count: number,
  index: number,
  removed: RescueRemovedMetadata[],
) => {
  if (count > 1 || index !== 0 || payload.length !== 10) {
    return malformed(
      'image/webp',
      'WebP VP8X chunk is malformed or misplaced.',
    );
  }
  const flags = payload[0];
  if (
    (flags & 0xc1) !== 0 ||
    payload[1] !== 0 ||
    payload[2] !== 0 ||
    payload[3] !== 0
  ) {
    return malformed('image/webp', 'WebP VP8X reserved bits must be zero.');
  }
  if ((flags & 0x08) !== 0) removed.push('webp:VP8X_EXIF_FLAG');
  if ((flags & 0x04) !== 0) removed.push('webp:VP8X_XMP_FLAG');
  const sanitized = Buffer.from(payload);
  sanitized[0] = flags & 0xf3;
  return sanitized;
};

const isWebpImageChunk = (fourCc: string) =>
  fourCc === 'VP8 ' || fourCc === 'VP8L' || fourCc === 'ANMF';

const stripWebpMetadata = (bytes: Buffer): StripResult => {
  validateWebpHeader(bytes);

  const chunks: Buffer[] = [];
  const removedMetadata: RescueRemovedMetadata[] = [];
  let offset = 12;
  let chunkIndex = 0;
  let vp8xCount = 0;
  let sawImagePayload = false;

  while (offset < bytes.length) {
    const { fourCc, payloadOffset, payloadEnd, chunkEnd } = readWebpChunk(
      bytes,
      offset,
    );

    if (fourCc === 'VP8X') {
      vp8xCount += 1;
      const payload = Buffer.from(bytes.subarray(payloadOffset, payloadEnd));
      chunks.push(
        buildRiffChunk(
          fourCc,
          sanitizeWebpExtendedPayload(
            payload,
            vp8xCount,
            chunkIndex,
            removedMetadata,
          ),
        ),
      );
    } else if (fourCc === 'EXIF') {
      removedMetadata.push('webp:EXIF');
    } else if (fourCc === 'XMP ') {
      removedMetadata.push('webp:XMP');
    } else {
      if (isWebpImageChunk(fourCc)) {
        sawImagePayload = true;
      }
      chunks.push(bytes.subarray(offset, chunkEnd));
    }

    offset = chunkEnd;
    chunkIndex += 1;
  }

  if (!sawImagePayload) {
    return malformed('image/webp', 'WebP does not contain an image payload.');
  }

  const sanitized = Buffer.concat([
    Buffer.from('RIFF\0\0\0\0WEBP', 'binary'),
    ...chunks,
  ]);
  sanitized.writeUInt32LE(sanitized.length - 8, 4);
  return { bytes: sanitized, removedMetadata };
};

type IsoBox = {
  start: number;
  end: number;
  headerSize: 8 | 16;
  sizeEncoding: '32' | '64' | 'zero';
  type: string;
};

const MP4_METADATA_BOXES = new Map<string, RescueRemovedMetadata>([
  ['udta', 'mp4:udta'],
  ['meta', 'mp4:meta'],
  ['ilst', 'mp4:ilst'],
  ['uuid', 'mp4:uuid'],
]);

const MP4_CONTAINER_BOXES = new Set([
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'edts',
  'dinf',
  'mvex',
  'moof',
  'traf',
  'mfra',
  'tref',
  'sinf',
  'schi',
]);

const parseIsoBox = (bytes: Buffer, start: number, limit: number): IsoBox => {
  if (limit - start < 8) {
    return malformed('video/mp4', 'MP4 box header is truncated.');
  }
  const size32 = bytes.readUInt32BE(start);
  const type = bytes.subarray(start + 4, start + 8).toString('latin1');
  let headerSize: 8 | 16 = 8;
  let end: number;
  let sizeEncoding: IsoBox['sizeEncoding'] = '32';

  if (size32 === 0) {
    sizeEncoding = 'zero';
    end = limit;
  } else if (size32 === 1) {
    headerSize = 16;
    sizeEncoding = '64';
    if (limit - start < headerSize) {
      return malformed('video/mp4', 'MP4 extended box header is truncated.');
    }
    const size64 = bytes.readBigUInt64BE(start + 8);
    if (size64 > BigInt(Number.MAX_SAFE_INTEGER)) {
      return malformed('video/mp4', 'MP4 box exceeds the safe size limit.');
    }
    end = start + Number(size64);
  } else {
    end = start + size32;
  }

  if (end - start < headerSize || end > limit) {
    return malformed('video/mp4', 'MP4 box size is invalid.');
  }
  return { start, end, headerSize, sizeEncoding, type };
};

const rebuildIsoBox = (bytes: Buffer, box: IsoBox, payload: Buffer) => {
  if (box.sizeEncoding === 'zero') {
    const header = Buffer.from(bytes.subarray(box.start, box.start + 8));
    header.writeUInt32BE(0, 0);
    return Buffer.concat([header, payload]);
  }
  const outputSize = box.headerSize + payload.length;
  const header = Buffer.from(
    bytes.subarray(box.start, box.start + box.headerSize),
  );
  if (box.sizeEncoding === '64') {
    header.writeUInt32BE(1, 0);
    header.writeBigUInt64BE(BigInt(outputSize), 8);
  } else {
    if (outputSize > 0xffffffff) {
      return malformed('video/mp4', 'Sanitized MP4 box exceeds 32-bit size.');
    }
    header.writeUInt32BE(outputSize, 0);
  }
  return Buffer.concat([header, payload]);
};

const stripIsoBoxRange = (
  bytes: Buffer,
  start: number,
  limit: number,
): StripResult => {
  const parts: Buffer[] = [];
  const removedMetadata: RescueRemovedMetadata[] = [];
  let offset = start;
  while (offset < limit) {
    const box = parseIsoBox(bytes, offset, limit);
    const removed = MP4_METADATA_BOXES.get(box.type);
    if (removed) {
      removedMetadata.push(removed);
    } else if (MP4_CONTAINER_BOXES.has(box.type)) {
      const nested = stripIsoBoxRange(
        bytes,
        box.start + box.headerSize,
        box.end,
      );
      parts.push(rebuildIsoBox(bytes, box, nested.bytes));
      removedMetadata.push(...nested.removedMetadata);
    } else {
      parts.push(bytes.subarray(box.start, box.end));
    }
    offset = box.end;
  }
  if (offset !== limit) {
    return malformed('video/mp4', 'MP4 box range does not end cleanly.');
  }
  return { bytes: Buffer.concat(parts), removedMetadata };
};

const stripMp4Metadata = (bytes: Buffer): StripResult => {
  if (bytes.length < 16 || !hasAsciiAt(bytes, 4, 'ftyp')) {
    return malformed('video/mp4', 'MP4 must start with an ftyp box.');
  }
  const first = parseIsoBox(bytes, 0, bytes.length);
  if (first.type !== 'ftyp' || first.sizeEncoding === 'zero') {
    return malformed(
      'video/mp4',
      'MP4 ftyp box must be first and have an explicit size.',
    );
  }
  const payloadSize = first.end - first.start - first.headerSize;
  if (payloadSize < 8 || (payloadSize - 8) % 4 !== 0) {
    return malformed('video/mp4', 'MP4 ftyp box size or brands are invalid.');
  }
  return stripIsoBoxRange(bytes, 0, bytes.length);
};

const stripMetadata = (
  detectedMimeType: RescueMediaMimeType,
  bytes: Buffer,
): StripResult => {
  if (detectedMimeType === 'image/jpeg') return stripJpegMetadata(bytes);
  if (detectedMimeType === 'image/png') return stripPngMetadata(bytes);
  if (detectedMimeType === 'image/webp') return stripWebpMetadata(bytes);
  return stripMp4Metadata(bytes);
};

export const sanitizeRescueMedia = (
  input: SanitizeRescueMediaInput,
): SanitizeRescueMediaResult => {
  const bytes = Buffer.from(input.bytes);
  const declaredMimeType = input.declaredMimeType.trim().toLowerCase();
  if (!SUPPORTED_MIME_TYPES.has(declaredMimeType)) {
    throw new RescueMediaSanitizationError(
      'unsupported_declared_mime',
      'Declared media MIME type is not supported.',
      { declaredMimeType },
    );
  }

  const detectedMimeType = detectRescueMediaMimeType(bytes);
  if (detectedMimeType !== declaredMimeType) {
    throw new RescueMediaSanitizationError(
      'mime_mismatch',
      'Detected media MIME type does not match the declared MIME type.',
      { declaredMimeType, detectedMimeType },
    );
  }

  const originalSha256 = createHash('sha256').update(bytes).digest('hex');
  const sanitized = stripMetadata(detectedMimeType, bytes);
  return {
    bytes: sanitized.bytes,
    originalSha256,
    originalSizeBytes: bytes.length,
    sanitizedSizeBytes: sanitized.bytes.length,
    declaredMimeType: declaredMimeType as RescueMediaMimeType,
    detectedMimeType,
    metadataRemoved: sanitized.removedMetadata.length > 0,
    removedMetadata: sanitized.removedMetadata,
  };
};
