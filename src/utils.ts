import { USDC_TOKEN } from './constants';


export const decodeQuotedPrintable = (str: string) => {
  // Remove soft line breaks
  str = str.replace(/=\r\n/g, '').replace(/=\n/g, '').replace(/=\r/g, '');

  // Decode encoded characters
  str = str.replace(/=([A-Fa-f0-9]{2})/g, (_, hex) => {
    return String.fromCharCode(parseInt(hex, 16));
  });

  return str;
}


// re-exported from bb.js/bigint-array
export function toBigIntBE(bytes: Uint8Array) {
  // A Buffer in node, *is* a Uint8Array. We can't refuse it's type.
  // However the algo below only works on an actual Uint8Array, hence we make a new one to be safe.
  bytes = new Uint8Array(bytes);
  let bigint = BigInt(0);
  const view = new DataView(bytes.buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    bigint = (bigint << BigInt(8)) + BigInt(view.getUint8(i));
  }
  return bigint;
}

export function toBufferBE(value: bigint, byteLength = 32) {
  const bytes = new Uint8Array(byteLength);
  const view = new DataView(bytes.buffer);
  for (let i = 0; i < byteLength; i++) {
    view.setUint8(byteLength - i - 1, Number(value & BigInt(0xff)));
    value >>= BigInt(8);
  }
  return bytes;
}

/** Multiplies amount by USDC decimals */
export const toUSDCDecimals = (amount: bigint) => amount * 10n ** BigInt(USDC_TOKEN.decimals);

/** Divides amount by USDC decimals */
export const fromUSDCDecimals = (amount: bigint) => amount / 10n ** BigInt(USDC_TOKEN.decimals);

/** parses a string  */
export const parseStringBytes = (bytes: bigint[]): string => {
  const index0 = bytes.findIndex(byte => byte === 0n);
  const length = index0 === -1 ? bytes.length : index0;
  const buffer = new Uint8Array(bytes.map(byte => Number(byte)));
  return String.fromCharCode(...buffer.slice(0, length));
}