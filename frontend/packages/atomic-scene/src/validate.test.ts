import { describe, expect, it } from "vitest";

import {
  defaultViewerOptions,
  SceneValidationError,
  validateScene,
} from "./index";

describe("shared atomic scene contract", () => {
  it("keeps the common Materials Project scientific defaults", () => {
    const options = defaultViewerOptions();
    expect(options.theme).toBe("materials");
    expect(options.showUnitCell).toBe(true);
    expect(options.showPolyhedra).toBe(true);
    expect(options.radiusMode).toBe("atomic");
    expect(options.continuousMeasurement).toBe(false);
  });

  it("rejects malformed scenes at the contract boundary", () => {
    expect(() => validateScene({ schemaVersion: "2.0" })).toThrow(
      SceneValidationError,
    );
  });
});
