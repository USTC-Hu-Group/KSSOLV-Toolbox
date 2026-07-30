const table = new Uint32Array(256);
for (let value = 0; value < 256; value += 1) {
  let checksum = value;
  for (let bit = 0; bit < 8; bit += 1) {
    checksum = (checksum & 1) !== 0 ? 0xedb88320 ^ (checksum >>> 1) : checksum >>> 1;
  }
  table[value] = checksum >>> 0;
}

export const crc32 = (bytes: Uint8Array): number => {
  let checksum = 0xffffffff;
  for (const byte of bytes) checksum = table[(checksum ^ byte) & 0xff] ^ (checksum >>> 8);
  return (checksum ^ 0xffffffff) >>> 0;
};
