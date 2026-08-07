import { describe, expect, it } from 'vitest';

import {
  createProgressiveTileSequence,
  progressiveTileGrid,
  randomTileFadeDuration,
  randomTileUpdateCount,
} from './progressiveTiles';

describe('progressive Hero tile preview', () => {
  it('chooses near-square regions for landscape and portrait viewports', () => {
    const landscape = progressiveTileGrid(1280, 720);
    const portrait = progressiveTileGrid(720, 1280);

    expect(landscape).toEqual({ columns: 5, rows: 3, total: 15 });
    expect(portrait).toEqual({ columns: 3, rows: 6, total: 18 });
    expect(Math.abs(1280 / landscape.columns - 720 / landscape.rows)).toBeLessThan(20);
    expect(Math.abs(720 / portrait.columns - 1280 / portrait.rows)).toBeLessThan(30);
  });

  it('randomizes every pass without repeating a region inside the pass', () => {
    const grid = { columns: 3, rows: 2, total: 6 };
    const randomValues = [0.72, 0.11, 0.91, 0.34, 0.58, 0.23, 0.84, 0.46, 0.03, 0.67];
    let randomIndex = 0;
    const sequence = createProgressiveTileSequence(
      300,
      200,
      grid,
      () => randomValues[randomIndex++ % randomValues.length] ?? 0.5,
    );
    const firstPass = Array.from({ length: grid.total }, () => sequence.next());
    const secondPass = Array.from({ length: grid.total }, () => sequence.next());

    expect(new Set(firstPass.map((tile) => tile.index))).toEqual(new Set([1, 2, 3, 4, 5, 6]));
    expect(new Set(secondPass.map((tile) => tile.index))).toEqual(new Set([1, 2, 3, 4, 5, 6]));
    expect(firstPass.map((tile) => tile.index)).not.toEqual([1, 2, 3, 4, 5, 6]);
    expect(firstPass.every((tile) => tile.pass === 1)).toBe(true);
    expect(secondPass.every((tile) => tile.pass === 2)).toBe(true);
    expect(secondPass[0]?.index).not.toBe(firstPass[firstPass.length - 1]?.index);
  });

  it('covers every destination pixel without gaps', () => {
    const width = 1279;
    const height = 719;
    const grid = progressiveTileGrid(width, height);
    const sequence = createProgressiveTileSequence(width, height, grid, () => 0.42);
    const area = Array.from({ length: grid.total }, () => sequence.next()).reduce(
      (sum, tile) => sum + tile.width * tile.height,
      0,
    );

    expect(area).toBe(width * height);
  });

  it('varies the number of regions updated by each sample', () => {
    expect(randomTileUpdateCount(() => 0, 1, 5)).toBe(1);
    expect(randomTileUpdateCount(() => 0.5, 1, 5)).toBe(3);
    expect(randomTileUpdateCount(() => 0.999999, 1, 5)).toBe(5);
  });

  it('varies tile fades between half and seven tenths of a second', () => {
    expect(randomTileFadeDuration(() => 0)).toBe(500);
    expect(randomTileFadeDuration(() => 0.5)).toBe(600);
    expect(randomTileFadeDuration(() => 1)).toBe(700);
  });
});
