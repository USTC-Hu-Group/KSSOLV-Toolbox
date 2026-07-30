import { Box3, OrthographicCamera, Vector3 } from 'three';
import { describe, expect, it } from 'vitest';

import {
  DisposableStack,
  fitOrthographicCamera,
  restoreCamera,
  snapshotCamera,
} from './index';

describe('shared camera state', () => {
  it('round-trips every camera field at machine precision', () => {
    const camera = new OrthographicCamera(-4, 4, 3, -3, 0.01, 1000);
    camera.position.set(7, -3, 11);
    camera.up.set(0.2, 0.9, -0.1).normalize();
    camera.quaternion.setFromAxisAngle(new Vector3(1, 2, 3).normalize(), 1.17);
    camera.zoom = 2.75;
    const target = new Vector3(-2, 5, 0.5);
    const snapshot = snapshotCamera(camera, target);

    camera.position.setScalar(0);
    camera.quaternion.identity();
    camera.zoom = 1;
    target.setScalar(0);
    restoreCamera(camera, target, snapshot);

    expect(snapshotCamera(camera, target)).toEqual(snapshot);
  });

  it('fits bounds while preserving the exact quaternion', () => {
    const camera = new OrthographicCamera(-5, 5, 5, -5, 0.01, 1000);
    camera.position.set(8, 9, 10);
    camera.lookAt(0, 0, 0);
    const quaternion = camera.quaternion.clone();
    const target = new Vector3();

    fitOrthographicCamera(
      camera,
      target,
      new Box3(new Vector3(-12, -2, -1), new Vector3(8, 7, 5)),
    );

    expect(camera.quaternion.toArray()).toEqual(quaternion.toArray());
    expect(camera.zoom).toBeGreaterThan(0);
    expect(target.toArray()).toEqual([-2, 2.5, 2]);
  });

  it('disposes composed resources once and in reverse order', () => {
    const calls: number[] = [];
    const stack = new DisposableStack();
    stack.defer(() => calls.push(1));
    stack.defer(() => calls.push(2));
    stack.dispose();
    stack.dispose();

    expect(calls).toEqual([2, 1]);
  });
});
