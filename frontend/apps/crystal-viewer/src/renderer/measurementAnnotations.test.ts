import { describe, expect, it } from 'vitest';

import { angleArcPoints, parseMeasurementAnnotations } from './measurementAnnotations';

describe('measurement annotations', () => {
  it('parses MATLAB singleton rows and rejects malformed records', () => {
    const annotations = parseMeasurementAnnotations(
      JSON.stringify({
        annotations: [
          {
            id: 'measurement-1',
            kind: 'distance',
            label: 'Distance: 1.00000 Å',
            points: [0, 0, 0],
            segments: [0, 0, 0, 1, 0, 0],
            candidatePlaneIndices: [0],
          },
          { id: 'bad', kind: 'unknown' },
        ],
      }),
    );

    expect(annotations).toHaveLength(1);
    expect(annotations[0].points).toEqual([[0, 0, 0]]);
    expect(annotations[0].segments).toEqual([[0, 0, 0, 1, 0, 0]]);
    expect(annotations[0].candidatePlaneIndices).toEqual([0]);
  });

  it('builds a three-dimensional angle arc around the selected center', () => {
    const [annotation] = parseMeasurementAnnotations({
      annotations: [
        {
          id: 'measurement-2',
          kind: 'angle',
          label: 'Angle: 90°',
          points: [
            [1, 0, 0],
            [0, 0, 0],
            [0, 1, 0],
          ],
          segments: [],
        },
      ],
    });
    const arc = angleArcPoints(annotation, 5);

    expect(arc).toHaveLength(5);
    expect(arc[0]).toEqual([0.32, 0, 0]);
    expect(arc[4][0]).toBeCloseTo(0, 12);
    expect(arc[4][1]).toBeCloseTo(0.32, 12);
  });

  it('returns an empty collection for invalid transport JSON', () => {
    expect(parseMeasurementAnnotations('{broken')).toEqual([]);
    expect(parseMeasurementAnnotations({ annotations: 'not-an-array' })).toEqual([]);
  });
});
