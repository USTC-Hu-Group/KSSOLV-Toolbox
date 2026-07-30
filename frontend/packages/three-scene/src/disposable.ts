export interface Disposable {
  dispose(): void;
}

/** Compose idempotent cleanup for listeners, workers, GPU resources, and layers. */
export class DisposableStack implements Disposable {
  private disposed = false;
  private readonly items: Disposable[] = [];

  add<T extends Disposable>(item: T): T {
    if (this.disposed) item.dispose();
    else this.items.push(item);
    return item;
  }

  defer(callback: () => void): void {
    this.add({ dispose: callback });
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    for (const item of this.items.reverse()) item.dispose();
    this.items.length = 0;
  }
}
