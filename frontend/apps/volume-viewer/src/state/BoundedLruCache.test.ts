import { describe, expect, it, vi } from 'vitest';

import { BoundedLruCache } from './BoundedLruCache';

describe('BoundedLruCache', () => {
  it('evicts the least recently used entry by count', () => {
    const cache = new BoundedLruCache<string, Uint8Array>({
      maximumEntries: 2,
      maximumBytes: 100,
      byteLength: (value) => value.byteLength,
    });
    cache.set('a', new Uint8Array(2));
    cache.set('b', new Uint8Array(3));
    expect(cache.get('a')).toBeDefined();
    cache.set('c', new Uint8Array(4));
    expect(cache.get('b')).toBeUndefined();
    expect(cache.get('a')).toBeDefined();
    expect(cache.get('c')).toBeDefined();
  });

  it('enforces bytes and disposes replacement, eviction, oversize, and clear', () => {
    const dispose = vi.fn();
    const cache = new BoundedLruCache<string, Uint8Array>({
      maximumEntries: 4,
      maximumBytes: 6,
      byteLength: (value) => value.byteLength,
      dispose,
    });
    expect(cache.set('a', new Uint8Array(4))).toBe(true);
    expect(cache.set('b', new Uint8Array(4))).toBe(true);
    expect(cache.get('a')).toBeUndefined();
    expect(cache.byteLength).toBe(4);
    cache.set('b', new Uint8Array(2));
    expect(cache.byteLength).toBe(2);
    expect(cache.set('huge', new Uint8Array(10))).toBe(false);
    cache.clear();
    expect(cache.size).toBe(0);
    expect(cache.byteLength).toBe(0);
    expect(dispose).toHaveBeenCalledTimes(4);
  });

  it('rejects invalid limits and invalid size accounting', () => {
    expect(
      () =>
        new BoundedLruCache({
          maximumEntries: 0,
          maximumBytes: 1,
          byteLength: () => 0,
        }),
    ).toThrow(/positive/);
    const cache = new BoundedLruCache<string, string>({
      maximumEntries: 1,
      maximumBytes: 1,
      byteLength: () => Number.NaN,
    });
    expect(() => cache.set('a', 'a')).toThrow(/byteLength/);
  });

  it('serves a hot derived-volume cache hit within 100 ms', () => {
    const value = new Uint8Array(4 * 1024 * 1024);
    const cache = new BoundedLruCache<string, Uint8Array>({
      maximumEntries: 2,
      maximumBytes: 8 * 1024 * 1024,
      byteLength: (item) => item.byteLength,
    });
    cache.set('volume:channel:lod:parameters', value);
    const started = performance.now();
    const cached = cache.get('volume:channel:lod:parameters');
    const elapsed = performance.now() - started;
    expect(cached).toBe(value);
    expect(elapsed).toBeLessThan(100);
  });
});
