/* eslint-disable no-bitwise -- Test fixtures need binary CRC32 and container flags. */
import { createHash } from 'node:crypto';

import {
  detectRescueMediaMimeType,
  RescueMediaSanitizationError,
  type RescueMediaSanitizationFailureReason,
  sanitizeRescueMedia,
} from '../src/infrastructure/rescue-media-sanitizer';

const jpegSegment = (marker: number, payload: Buffer) => {
  const segment = Buffer.alloc(4 + payload.length);
  segment[0] = 0xff;
  segment[1] = marker;
  segment.writeUInt16BE(payload.length + 2, 2);
  payload.copy(segment, 4);
  return segment;
};

const makeJpeg = () =>
  Buffer.concat([
    Buffer.from([0xff, 0xd8]),
    jpegSegment(0xe0, Buffer.from('JFIF-safe', 'ascii')),
    jpegSegment(0xe1, Buffer.from('Exif\0\0GPS-location', 'binary')),
    jpegSegment(0xed, Buffer.from('IPTC-private', 'ascii')),
    jpegSegment(0xfe, Buffer.from('camera comment', 'ascii')),
    jpegSegment(0xda, Buffer.from([0x01, 0x01, 0x00, 0x00, 0x3f, 0x00])),
    Buffer.from([0x11, 0x22, 0xff, 0x00, 0x33, 0xff, 0xd0, 0x44]),
    Buffer.from([0xff, 0xd9]),
  ]);

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

const pngChunk = (type: string, payload: Buffer) => {
  const typeBytes = Buffer.from(type, 'ascii');
  const chunk = Buffer.alloc(12 + payload.length);
  chunk.writeUInt32BE(payload.length, 0);
  typeBytes.copy(chunk, 4);
  payload.copy(chunk, 8);
  chunk.writeUInt32BE(
    crc32(Buffer.concat([typeBytes, payload])),
    8 + payload.length,
  );
  return chunk;
};

const makePng = () => {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(1, 0);
  header.writeUInt32BE(1, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk('IHDR', header),
    pngChunk('eXIf', Buffer.from('GPS', 'ascii')),
    pngChunk('tEXt', Buffer.from('Comment\0private', 'binary')),
    pngChunk('zTXt', Buffer.from('compressed text', 'ascii')),
    pngChunk('iTXt', Buffer.from('international text', 'ascii')),
    pngChunk('tIME', Buffer.from([0x07, 0xea, 0x07, 0x15, 0x10, 0x20, 0x30])),
    pngChunk('IDAT', Buffer.from([0x78, 0x9c, 0x00])),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
};

const riffChunk = (fourCc: string, payload: Buffer) => {
  const chunk = Buffer.alloc(8 + payload.length + (payload.length % 2));
  chunk.write(fourCc, 0, 4, 'ascii');
  chunk.writeUInt32LE(payload.length, 4);
  payload.copy(chunk, 8);
  return chunk;
};

const makeWebp = () => {
  const vp8x = Buffer.alloc(10);
  vp8x[0] = 0x0c;
  const chunks = [
    riffChunk('VP8X', vp8x),
    riffChunk('VP8 ', Buffer.from([0x01, 0x02, 0x03])),
    riffChunk('EXIF', Buffer.from('gps-exif', 'ascii')),
    riffChunk('XMP ', Buffer.from('private-xmp', 'ascii')),
  ];
  const bytes = Buffer.concat([
    Buffer.from('RIFF\0\0\0\0WEBP', 'binary'),
    ...chunks,
  ]);
  bytes.writeUInt32LE(bytes.length - 8, 4);
  return bytes;
};

const makeMp4 = () => {
  const bytes = Buffer.alloc(24);
  bytes.writeUInt32BE(bytes.length, 0);
  bytes.write('ftyp', 4, 4, 'ascii');
  bytes.write('isom', 8, 4, 'ascii');
  bytes.writeUInt32BE(0x200, 12);
  bytes.write('isom', 16, 4, 'ascii');
  bytes.write('mp42', 20, 4, 'ascii');
  return bytes;
};

const isoBox = (type: string, payload: Buffer) => {
  const bytes = Buffer.alloc(8 + payload.length);
  bytes.writeUInt32BE(bytes.length, 0);
  bytes.write(type, 4, 4, 'latin1');
  payload.copy(bytes, 8);
  return bytes;
};

const makeMp4WithMetadata = () =>
  Buffer.concat([
    makeMp4(),
    isoBox(
      'moov',
      Buffer.concat([
        isoBox('mvhd', Buffer.from('technical-timeline', 'ascii')),
        isoBox('udta', Buffer.from('location=+10.776+106.700/', 'ascii')),
        isoBox('meta', Buffer.from('quicktime-location-metadata', 'ascii')),
        isoBox('ilst', Buffer.from('copyright-location', 'ascii')),
        isoBox(
          'trak',
          Buffer.concat([
            isoBox('tkhd', Buffer.from('technical-track', 'ascii')),
            isoBox('uuid', Buffer.from('private-xmp-location', 'ascii')),
          ]),
        ),
      ]),
    ),
    isoBox('uuid', Buffer.from('top-level-private-xmp', 'ascii')),
    isoBox('mdat', Buffer.from([0x01, 0x02, 0x03, 0x04])),
  ]);

const readIsoBoxTypes = (bytes: Buffer, start = 0, limit = bytes.length) => {
  const types: string[] = [];
  let offset = start;
  while (offset < limit) {
    const size = bytes.readUInt32BE(offset);
    types.push(bytes.subarray(offset + 4, offset + 8).toString('latin1'));
    offset += size === 0 ? limit - offset : size;
  }
  return types;
};

const readPngChunkTypes = (bytes: Buffer) => {
  const types: string[] = [];
  let offset = 8;
  while (offset < bytes.length) {
    const length = bytes.readUInt32BE(offset);
    types.push(bytes.subarray(offset + 4, offset + 8).toString('ascii'));
    offset += 12 + length;
  }
  return types;
};

const readWebpChunks = (bytes: Buffer) => {
  const chunks: Array<{ fourCc: string; payload: Buffer }> = [];
  let offset = 12;
  while (offset < bytes.length) {
    const fourCc = bytes.subarray(offset, offset + 4).toString('ascii');
    const length = bytes.readUInt32LE(offset + 4);
    chunks.push({
      fourCc,
      payload: bytes.subarray(offset + 8, offset + 8 + length),
    });
    offset += 8 + length + (length % 2);
  }
  return chunks;
};

const expectReason = (
  operation: () => unknown,
  reason: RescueMediaSanitizationFailureReason,
) => {
  try {
    operation();
    throw new Error('Expected media sanitization to fail.');
  } catch (error) {
    expect(error).toBeInstanceOf(RescueMediaSanitizationError);
    expect((error as RescueMediaSanitizationError).reason).toBe(reason);
  }
};

describe('rescue media sanitizer', () => {
  it('detects JPEG, PNG, WebP and MP4 from their magic bytes', () => {
    expect(detectRescueMediaMimeType(makeJpeg())).toBe('image/jpeg');
    expect(detectRescueMediaMimeType(makePng())).toBe('image/png');
    expect(detectRescueMediaMimeType(makeWebp())).toBe('image/webp');
    expect(detectRescueMediaMimeType(makeMp4())).toBe('video/mp4');
  });

  it('removes MP4 location/user metadata while preserving core media boxes', () => {
    const original = makeMp4WithMetadata();
    const result = sanitizeRescueMedia({
      bytes: original,
      declaredMimeType: 'video/mp4',
    });

    expect(result.detectedMimeType).toBe('video/mp4');
    expect(result.metadataRemoved).toBe(true);
    expect(result.removedMetadata).toEqual([
      'mp4:udta',
      'mp4:meta',
      'mp4:ilst',
      'mp4:uuid',
      'mp4:uuid',
    ]);
    expect(readIsoBoxTypes(result.bytes)).toEqual(['ftyp', 'moov', 'mdat']);
    expect(result.bytes.includes(Buffer.from('technical-timeline'))).toBe(true);
    expect(result.bytes.includes(Buffer.from('technical-track'))).toBe(true);
    expect(result.bytes.includes(Buffer.from('location='))).toBe(false);
    expect(result.bytes.includes(Buffer.from('private-xmp'))).toBe(false);
  });

  it('fails closed when a nested MP4 box overruns its parent', () => {
    const invalidChild = Buffer.alloc(8);
    invalidChild.writeUInt32BE(32, 0);
    invalidChild.write('udta', 4, 4, 'ascii');
    const malformedMp4 = Buffer.concat([
      makeMp4(),
      isoBox('moov', invalidChild),
    ]);

    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: malformedMp4,
          declaredMimeType: 'video/mp4',
        }),
      'malformed_container',
    );
  });

  it('hashes original JPEG bytes and removes APP1, APP13 and COM segments', () => {
    const original = makeJpeg();
    const originalCopy = Buffer.from(original);
    const result = sanitizeRescueMedia({
      bytes: original,
      declaredMimeType: 'image/jpeg',
    });

    expect(result.originalSha256).toBe(
      createHash('sha256').update(original).digest('hex'),
    );
    expect(result.removedMetadata).toEqual([
      'jpeg:APP1',
      'jpeg:APP13',
      'jpeg:COM',
    ]);
    expect(result.metadataRemoved).toBe(true);
    expect(result.bytes.includes(Buffer.from('JFIF-safe', 'ascii'))).toBe(true);
    expect(result.bytes.includes(Buffer.from('GPS-location', 'ascii'))).toBe(
      false,
    );
    expect(result.bytes.includes(Buffer.from('IPTC-private', 'ascii'))).toBe(
      false,
    );
    expect(result.bytes.includes(Buffer.from('camera comment', 'ascii'))).toBe(
      false,
    );
    expect(result.bytes.subarray(-2)).toEqual(Buffer.from([0xff, 0xd9]));
    expect(original).toEqual(originalCopy);
  });

  it('removes PNG EXIF, text and time chunks while preserving a valid structure', () => {
    const result = sanitizeRescueMedia({
      bytes: makePng(),
      declaredMimeType: 'image/png',
    });

    expect(result.removedMetadata).toEqual([
      'png:eXIf',
      'png:tEXt',
      'png:zTXt',
      'png:iTXt',
      'png:tIME',
    ]);
    expect(readPngChunkTypes(result.bytes)).toEqual(['IHDR', 'IDAT', 'IEND']);
    const secondPass = sanitizeRescueMedia({
      bytes: result.bytes,
      declaredMimeType: 'image/png',
    });
    expect(secondPass.metadataRemoved).toBe(false);
    expect(secondPass.bytes).toEqual(result.bytes);
  });

  it('removes WebP EXIF/XMP chunks, clears VP8X flags and recomputes RIFF size', () => {
    const result = sanitizeRescueMedia({
      bytes: makeWebp(),
      declaredMimeType: 'image/webp',
    });
    const chunks = readWebpChunks(result.bytes);

    expect(result.removedMetadata).toEqual([
      'webp:VP8X_EXIF_FLAG',
      'webp:VP8X_XMP_FLAG',
      'webp:EXIF',
      'webp:XMP',
    ]);
    expect(chunks.map((chunk) => chunk.fourCc)).toEqual(['VP8X', 'VP8 ']);
    expect(chunks[0].payload[0]).toBe(0);
    expect(result.bytes.readUInt32LE(4)).toBe(result.bytes.length - 8);
    const secondPass = sanitizeRescueMedia({
      bytes: result.bytes,
      declaredMimeType: 'image/webp',
    });
    expect(secondPass.metadataRemoved).toBe(false);
    expect(secondPass.bytes).toEqual(result.bytes);
  });

  it('validates MP4 ftyp and preserves the original bytes', () => {
    const original = makeMp4();
    const result = sanitizeRescueMedia({
      bytes: original,
      declaredMimeType: 'video/mp4',
    });

    expect(result.metadataRemoved).toBe(false);
    expect(result.removedMetadata).toEqual([]);
    expect(result.bytes).toEqual(original);
    expect(result.bytes).not.toBe(original);
  });

  it('fails closed with typed reasons for unsupported, unknown and mismatched MIME', () => {
    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: makePng(),
          declaredMimeType: 'image/gif',
        }),
      'unsupported_declared_mime',
    );
    expectReason(
      () => detectRescueMediaMimeType(Buffer.alloc(0)),
      'empty_bytes',
    );
    expectReason(
      () => detectRescueMediaMimeType(Buffer.from('not-media', 'ascii')),
      'unrecognized_magic',
    );
    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: makePng(),
          declaredMimeType: 'image/jpeg',
        }),
      'mime_mismatch',
    );
  });

  it('fails closed for malformed JPEG, PNG, WebP and MP4 containers', () => {
    const corruptPng = makePng();
    corruptPng[corruptPng.length - 5] ^= 0xff;
    const corruptWebp = makeWebp();
    corruptWebp.writeUInt32LE(corruptWebp.length, 4);
    const corruptMp4 = makeMp4();
    corruptMp4.writeUInt32BE(12, 0);

    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
          declaredMimeType: 'image/jpeg',
        }),
      'malformed_container',
    );
    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: corruptPng,
          declaredMimeType: 'image/png',
        }),
      'malformed_container',
    );
    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: corruptWebp,
          declaredMimeType: 'image/webp',
        }),
      'malformed_container',
    );
    expectReason(
      () =>
        sanitizeRescueMedia({
          bytes: corruptMp4,
          declaredMimeType: 'video/mp4',
        }),
      'malformed_container',
    );
  });
});
