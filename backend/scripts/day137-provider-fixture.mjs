import {deflateSync} from 'node:zlib';
const crc32=bytes=>{let crc=0xffffffff;for(const byte of bytes){crc^=byte;for(let bit=0;bit<8;bit++)crc=crc&1?(crc>>>1)^0xedb88320:crc>>>1;}return (crc^0xffffffff)>>>0;};
const chunk=(type,bytes)=>{const t=Buffer.from(type),b=Buffer.alloc(bytes.length+12);b.writeUInt32BE(bytes.length);t.copy(b,4);bytes.copy(b,8);b.writeUInt32BE(crc32(Buffer.concat([t,bytes])),bytes.length+8);return b;};
export function makeProviderPng(){
 const header=Buffer.alloc(13);header.writeUInt32BE(1);header.writeUInt32BE(1,4);header[8]=8;header[9]=2;
 return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',header),chunk('tEXt',Buffer.from('Comment\0Day137 synthetic metadata')),chunk('IDAT',deflateSync(Buffer.from([0,149,213,178]))),chunk('IEND',Buffer.alloc(0))]);
}
