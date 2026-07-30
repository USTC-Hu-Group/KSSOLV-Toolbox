/** Shared typed bridge for MATLAB uihtml custom events. */
export interface MatlabEvent {
  Data?: unknown;
}

export interface MatlabHtmlComponent {
  Data?: unknown;
  addEventListener(name: string, handler: (event: MatlabEvent) => void): void;
  sendEventToMATLAB(name: string, data?: unknown): void;
}

type EventHandler = (data: unknown) => void;

const unwrapEventData = (event: MatlabEvent | unknown): unknown => {
  if (typeof event === 'object' && event !== null && 'Data' in event) {
    return (event as MatlabEvent).Data;
  }
  return event;
};

const decodeLegacyJson = (value: unknown): unknown => {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return value;
  try {
    return JSON.parse(trimmed) as unknown;
  } catch {
    return value;
  }
};

export class MatlabBridge {
  private component?: MatlabHtmlComponent;
  private readonly handlers = new Map<string, Set<EventHandler>>();
  private readonly registeredEvents = new Set<string>();

  get connected(): boolean {
    return this.component !== undefined;
  }

  attach(component: MatlabHtmlComponent): void {
    if (this.component === component) return;
    this.component = component;
    for (const eventName of this.handlers.keys()) {
      this.register(eventName);
    }
  }

  on(eventName: string, handler: EventHandler): () => void {
    const handlers = this.handlers.get(eventName) ?? new Set<EventHandler>();
    handlers.add(handler);
    this.handlers.set(eventName, handlers);
    this.register(eventName);
    return () => {
      handlers.delete(handler);
    };
  }

  emit(eventName: string, data?: unknown): void {
    this.component?.sendEventToMATLAB(eventName, data);
  }

  dispatchForTesting(eventName: string, data?: unknown): void {
    this.dispatch(eventName, data);
  }

  private register(eventName: string): void {
    if (!this.component || this.registeredEvents.has(eventName)) return;
    this.component.addEventListener(eventName, (event) => {
      this.dispatch(eventName, decodeLegacyJson(unwrapEventData(event)));
    });
    this.registeredEvents.add(eventName);
  }

  private dispatch(eventName: string, data: unknown): void {
    for (const handler of this.handlers.get(eventName) ?? []) {
      handler(data);
    }
  }
}

export const matlabBridge = new MatlabBridge();
