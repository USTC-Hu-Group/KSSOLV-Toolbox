export interface ProgressiveTileGrid {
  columns: number;
  rows: number;
  total: number;
}

export interface ProgressiveTile {
  column: number;
  row: number;
  index: number;
  pass: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ProgressiveTileSequence {
  next: () => ProgressiveTile;
}

export const progressiveTileGrid = (
  width: number,
  height: number,
  targetTiles = 18,
): ProgressiveTileGrid => {
  const safeWidth = Math.max(Math.round(width), 1);
  const safeHeight = Math.max(Math.round(height), 1);
  const aspect = safeWidth / safeHeight;
  const rows = Math.max(1, Math.round(Math.sqrt(Math.max(targetTiles, 1) / aspect)));
  const columns = Math.max(1, Math.round(rows * aspect));
  return { columns, rows, total: columns * rows };
};

const shuffledTileIndices = (total: number, random: () => number): number[] => {
  const indices = Array.from({ length: total }, (_, index) => index);
  for (let index = indices.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.min(Math.max(random(), 0), 0.999999) * (index + 1));
    [indices[index], indices[swapIndex]] = [indices[swapIndex], indices[index]];
  }
  return indices;
};

export const createProgressiveTileSequence = (
  width: number,
  height: number,
  grid = progressiveTileGrid(width, height),
  random: () => number = Math.random,
): ProgressiveTileSequence => {
  let order = shuffledTileIndices(grid.total, random);
  let cursor = 0;
  let pass = 1;
  let previousIndex = -1;

  const refill = (): void => {
    order = shuffledTileIndices(grid.total, random);
    if (grid.total > 1 && order[0] === previousIndex) {
      const swapIndex =
        1 + Math.floor(Math.min(Math.max(random(), 0), 0.999999) * (grid.total - 1));
      [order[0], order[swapIndex]] = [order[swapIndex], order[0]];
    }
    cursor = 0;
    pass += 1;
  };

  return {
    next: () => {
      if (cursor >= grid.total) refill();
      const tileIndex = order[cursor] ?? 0;
      previousIndex = tileIndex;
      cursor += 1;
      const row = Math.floor(tileIndex / grid.columns);
      const column = tileIndex % grid.columns;
      const x = Math.floor((column * width) / grid.columns);
      const y = Math.floor((row * height) / grid.rows);
      const right = Math.floor(((column + 1) * width) / grid.columns);
      const bottom = Math.floor(((row + 1) * height) / grid.rows);
      return {
        column,
        row,
        index: tileIndex + 1,
        pass,
        x,
        y,
        width: right - x,
        height: bottom - y,
      };
    },
  };
};

export const randomTileUpdateCount = (
  random: () => number = Math.random,
  minimumTiles = 1,
  maximumTiles = 5,
): number => {
  const minimum = Math.max(Math.round(minimumTiles), 1);
  const maximum = Math.max(Math.round(maximumTiles), minimum);
  return minimum + Math.floor(Math.min(Math.max(random(), 0), 0.999999) * (maximum - minimum + 1));
};

export const randomTileFadeDuration = (
  random: () => number = Math.random,
  minimumMilliseconds = 500,
  maximumMilliseconds = 700,
): number => {
  const minimum = Math.max(Math.round(minimumMilliseconds), 0);
  const maximum = Math.max(Math.round(maximumMilliseconds), minimum);
  return Math.round(minimum + Math.min(Math.max(random(), 0), 1) * (maximum - minimum));
};
