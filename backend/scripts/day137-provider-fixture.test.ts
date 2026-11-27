import test from 'node:test';import assert from 'node:assert/strict';
import {sanitizeRescueMedia} from '../src/infrastructure/rescue-media-sanitizer';
import {makeProviderPng} from './day137-provider-fixture.mjs';
const old=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z7dQAAAAASUVORK5CYII=','base64');
test('counterfactual old arbitrary fixture is rejected for invalid CRC',()=>assert.throws(()=>sanitizeRescueMedia({bytes:old,declaredMimeType:'image/png'}),/invalid CRC/));
test('valid one-pixel real PNG is sanitized and metadata removed',()=>{const b=makeProviderPng(),s=sanitizeRescueMedia({bytes:b,declaredMimeType:'image/png'});assert.equal(s.bytes.readUInt32BE(16),1);assert.equal(s.bytes.readUInt32BE(20),1);assert.equal(s.detectedMimeType,'image/png');assert(!s.bytes.includes(Buffer.from('Day137 synthetic metadata')));assert(b.includes(Buffer.from('Day137 synthetic metadata')));assert(s.bytes.length<b.length);});
test('deterministic image fixture',()=>assert(makeProviderPng().equals(makeProviderPng())));
