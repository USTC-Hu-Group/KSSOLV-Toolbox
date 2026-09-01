# Modeling API v1

The Modeling API applies versioned, headless modeling commands to a model. Use
it for scripts, reproducible recipes, and batch preparation. Interactive users
should begin with the [Modeling User Guide](modeling-user-guide.md).

## Execute a command

Call `kssolv.api.v1.modeling.execute(model, request)` with a request containing
the schema version, command ID, and command parameters:

```matlab
request = struct( ...
    "schemaVersion", 1, ...
    "commandId", "translate_atoms", ...
    "parameters", struct( ...
        "indices", 1, ...
        "vector", [0.1, 0, 0], ...
        "fractional", false));

response = kssolv.api.v1.modeling.execute(model, request);
```

The response reports whether the model changed, provides a user-readable
message, and returns a defensive result model. It also includes parent and
result hashes that can be used to verify an operation chain.

Requests with an unsupported schema fail with
`KSSOLV:API:ModelingSchema`; they are not interpreted as version 1. Validate
indices, units, and periodic-coordinate choices before submitting a command.

## Record and replay

`OperationRecorder` records commands, complete parameters, seeds, hashes, and
timestamps. Save a recipe when the same preparation must be audited or applied
again:

```matlab
recorder = kssolv.modeling.provenance.OperationRecorder();
[response, record] = recorder.execute( ...
    model, "translate_atoms", parameters);
recorder.save("recipe.json");

[replayed, report] = ...
    kssolv.modeling.provenance.OperationRecorder.replay( ...
    model, "recipe.json");
```

Replay verifies the parent and result hashes. A mismatch stops replay instead
of silently applying later commands to an unexpected model.

## Batch execution

Use `BatchModeler.run` for in-memory models and request arrays:

```matlab
report = kssolv.modeling.BatchModeler.run(models, requests, ...
    progressFcn = @(done, total)fprintf("%d/%d\n", done, total), ...
    cancelFcn = @()false);
```

Each item receives its own model copy. A failure is reported for that item and
does not mutate another batch item. Use `FileBatchModeler` when the workflow
also needs file import, validation, export, and per-file error reporting.

## Recovery

Recovery snapshots can be scanned and loaded without replacing the original
project:

```matlab
entries = kssolv.modeling.provenance.RecoveryJournal.scan();
valid = entries([entries.valid]);
snapshot = ...
    kssolv.modeling.provenance.RecoveryJournal.load(valid(1).path);
model = snapshot.model;
```

Check that `valid` is nonempty and inspect the selected entry before loading
it. Snapshots with unreadable data, unknown schemas, document mismatches, or
hash mismatches are rejected and retained for diagnosis.
