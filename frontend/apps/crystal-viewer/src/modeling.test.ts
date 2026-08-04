import { describe, expect, it } from 'vitest';

import { isContextModelingResult, modelingBackendAvailable } from './modeling';

describe('context modeling protocol', () => {
  it('recognizes only supported result payloads', () => {
    expect(
      isContextModelingResult({
        commandId: 'move_atoms',
        status: 'success',
        message: '',
      }),
    ).toBe(true);
    expect(
      isContextModelingResult({ commandId: 'sort_atoms', status: 'success', message: '' }),
    ).toBe(false);
    expect(
      isContextModelingResult({ commandId: 'move_atoms', status: 'waiting', message: '' }),
    ).toBe(false);
  });

  it('marks exported HTML as backend-free', () => {
    const previous = document.documentElement.dataset.kssolvOffline;
    document.documentElement.dataset.kssolvOffline = 'true';
    expect(modelingBackendAvailable()).toBe(false);
    if (previous === undefined) delete document.documentElement.dataset.kssolvOffline;
    else document.documentElement.dataset.kssolvOffline = previous;
    expect(modelingBackendAvailable()).toBe(true);
  });
});
