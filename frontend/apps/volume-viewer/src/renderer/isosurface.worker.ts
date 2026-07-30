/// <reference lib="webworker" />

import { marchingTetrahedra, wrapPeriodicGrid } from './isosurface';

interface Request {
  id: number;
  dimensions: [number, number, number];
  threshold: number;
  periodic: [boolean, boolean, boolean];
  values: ArrayBuffer;
}

self.onmessage = (event: MessageEvent<Request>): void => {
  try {
    const request = event.data;
    const expanded = wrapPeriodicGrid(
      new Float32Array(request.values),
      request.dimensions,
      request.periodic,
    );
    const result = marchingTetrahedra(
      expanded.values,
      expanded.dimensions,
      request.threshold,
    );
    self.postMessage(
      {
        id: request.id,
        positions: result.positions.buffer,
        truncated: result.truncated,
      },
      { transfer: [result.positions.buffer] },
    );
  } catch (error) {
    self.postMessage({
      id: event.data.id,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};
