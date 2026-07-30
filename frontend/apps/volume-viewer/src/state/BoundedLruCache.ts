export interface BoundedLruCacheOptions<K, V> {
  maximumEntries: number;
  maximumBytes: number;
  byteLength: (value: V, key: K) => number;
  dispose?: (value: V, key: K) => void;
}

/**
 * Deterministic insertion-order LRU used for CPU-side derived volume data.
 * Values are disposed both on eviction and explicit clear.
 */
export class BoundedLruCache<K, V> {
  private readonly entries = new Map<K, { value: V; bytes: number }>();
  private bytes = 0;

  constructor(private readonly options: BoundedLruCacheOptions<K, V>) {
    if (
      !Number.isInteger(options.maximumEntries) ||
      options.maximumEntries < 1 ||
      !Number.isFinite(options.maximumBytes) ||
      options.maximumBytes < 1
    ) {
      throw new Error('LRU limits must be positive finite values.');
    }
  }

  get size(): number {
    return this.entries.size;
  }

  get byteLength(): number {
    return this.bytes;
  }

  get(key: K): V | undefined {
    const entry = this.entries.get(key);
    if (!entry) return undefined;
    this.entries.delete(key);
    this.entries.set(key, entry);
    return entry.value;
  }

  set(key: K, value: V): boolean {
    const bytes = this.options.byteLength(value, key);
    if (!Number.isFinite(bytes) || bytes < 0) {
      throw new Error('LRU byteLength must return a non-negative finite value.');
    }
    const previous = this.entries.get(key);
    if (previous) {
      this.entries.delete(key);
      this.bytes -= previous.bytes;
      this.options.dispose?.(previous.value, key);
    }
    if (bytes > this.options.maximumBytes) {
      this.options.dispose?.(value, key);
      return false;
    }
    this.entries.set(key, { value, bytes });
    this.bytes += bytes;
    this.evict();
    return true;
  }

  clear(): void {
    for (const [key, entry] of this.entries) {
      this.options.dispose?.(entry.value, key);
    }
    this.entries.clear();
    this.bytes = 0;
  }

  private evict(): void {
    while (
      this.entries.size > this.options.maximumEntries ||
      this.bytes > this.options.maximumBytes
    ) {
      const oldestKey = this.entries.keys().next().value as K | undefined;
      if (oldestKey === undefined) return;
      const oldest = this.entries.get(oldestKey);
      if (!oldest) return;
      this.entries.delete(oldestKey);
      this.bytes -= oldest.bytes;
      this.options.dispose?.(oldest.value, oldestKey);
    }
  }
}
