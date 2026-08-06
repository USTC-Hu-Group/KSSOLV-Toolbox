import { describe, expect, it, vi } from 'vitest';

import { MatlabBridge, type MatlabEvent, type MatlabHtmlComponent } from './matlabBridge';

class MockComponent implements MatlabHtmlComponent {
  readonly listeners = new Map<string, (event: MatlabEvent) => void>();
  readonly sendEventToMATLAB = vi.fn();

  addEventListener(name: string, handler: (event: MatlabEvent) => void): void {
    this.listeners.set(name, handler);
  }

  dispatch(name: string, data: unknown): void {
    this.listeners.get(name)?.({ Data: data });
  }
}

describe('MatlabBridge', () => {
  it('registers subscriptions made before and after attachment', () => {
    const bridge = new MatlabBridge();
    const component = new MockComponent();
    const first = vi.fn();
    const second = vi.fn();
    bridge.on('scene:set', first);
    bridge.attach(component);
    bridge.on('theme:set', second);
    component.dispatch('scene:set', { schemaVersion: '1.0' });
    component.dispatch('theme:set', 'pretty');
    expect(first).toHaveBeenCalledWith({ schemaVersion: '1.0' });
    expect(second).toHaveBeenCalledWith('pretty');
  });

  it('decodes legacy JSON while preserving native event objects', () => {
    const bridge = new MatlabBridge();
    const component = new MockComponent();
    bridge.attach(component);
    const handler = vi.fn();
    bridge.on('event', handler);
    component.dispatch('event', '{"value":3}');
    component.dispatch('event', { value: 4 });
    expect(handler).toHaveBeenNthCalledWith(1, { value: 3 });
    expect(handler).toHaveBeenNthCalledWith(2, { value: 4 });
  });

  it('sends native data back to MATLAB', () => {
    const bridge = new MatlabBridge();
    const component = new MockComponent();
    bridge.attach(component);
    bridge.emit('viewer:ready', { schemaVersion: '1.0' });
    expect(component.sendEventToMATLAB).toHaveBeenCalledWith('viewer:ready', {
      schemaVersion: '1.0',
    });
  });

  it('receives reliable DataChanged bridge envelopes', () => {
    const bridge = new MatlabBridge();
    const component = new MockComponent();
    const handler = vi.fn();
    bridge.on('image:exportDestination', handler);
    bridge.attach(component);
    component.dispatch('DataChanged', {
      kssolvEvent: 'image:exportDestination',
      payload: { requestId: 'export-1', status: 'ready' },
      serial: 1,
    });
    expect(handler).toHaveBeenCalledWith({ requestId: 'export-1', status: 'ready' });
  });
});
