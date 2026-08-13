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

interface BridgeDataEnvelope {
  kssolvEvent: string;
  payload?: unknown;
}

const unwrapEventData = (event: MatlabEvent | unknown): unknown => {
  if (typeof event === "object" && event !== null && "Data" in event) {
    return (event as MatlabEvent).Data;
  }
  return event;
};

const decodeLegacyJson = (value: unknown): unknown => {
  if (typeof value !== "string") return value;
  const trimmed = value.trim();
  if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) return value;
  try {
    return JSON.parse(trimmed) as unknown;
  } catch {
    return value;
  }
};

const bridgeDataEnvelope = (value: unknown): BridgeDataEnvelope | undefined => {
  const decoded = decodeLegacyJson(value);
  if (
    typeof decoded !== "object" ||
    decoded === null ||
    !("kssolvEvent" in decoded) ||
    typeof decoded.kssolvEvent !== "string"
  ) {
    return undefined;
  }
  return decoded as BridgeDataEnvelope;
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
    this.registeredEvents.clear();
    component.addEventListener("DataChanged", (event) => {
      const envelope = bridgeDataEnvelope(
        unwrapEventData(event) ?? component.Data,
      );
      if (envelope) this.dispatch(envelope.kssolvEvent, envelope.payload);
    });
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

/**
 * Prevent Chromium/CEF page zoom while preserving ordinary scrolling and
 * application-owned canvas zoom. Embedded KSSOLV surfaces must stay aligned
 * with the native MATLAB layout even when a trackpad emits pinch gestures.
 */
export const installEmbeddedBrowserZoomGuard = (target: Window = window): (() => void) => {
  const preventModifiedWheel = (event: WheelEvent): void => {
    if (event.ctrlKey || event.metaKey) event.preventDefault();
  };
  const preventGesture = (event: Event): void => event.preventDefault();
  const preventZoomChord = (event: KeyboardEvent): void => {
    const primaryModifier = event.ctrlKey !== event.metaKey && (event.ctrlKey || event.metaKey);
    if (!primaryModifier || !['+', '=', '-', '_', '0'].includes(event.key)) return;
    event.preventDefault();
  };
  target.addEventListener('wheel', preventModifiedWheel, { capture: true, passive: false });
  target.addEventListener('keydown', preventZoomChord, true);
  target.addEventListener('gesturestart', preventGesture, true);
  target.addEventListener('gesturechange', preventGesture, true);
  return () => {
    target.removeEventListener('wheel', preventModifiedWheel, true);
    target.removeEventListener('keydown', preventZoomChord, true);
    target.removeEventListener('gesturestart', preventGesture, true);
    target.removeEventListener('gesturechange', preventGesture, true);
  };
};
