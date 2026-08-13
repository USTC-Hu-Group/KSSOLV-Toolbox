# Modeling API v1

The stable headless entry point is `kssolv.api.v1.modeling.execute(model, request)`.

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

The response includes `schemaVersion`, `commandId`, `changed`, `message`,
`parentHash`, `resultHash`, and a defensive result model. Unsupported schemas
fail with `KSSOLV:API:ModelingSchema`; they are never interpreted as v1.

## Record and replay

```matlab
recorder = kssolv.modeling.provenance.OperationRecorder();
[response, record] = recorder.execute(model, "translate_atoms", parameters);
recorder.save("recipe.json");
[replayed, report] = ...
    kssolv.modeling.provenance.OperationRecorder.replay(model, "recipe.json");
```

Replay verifies every parent and result SHA-256. `RecipeLibrary` stores named
recipes under a versioned user directory using atomic replacement.

## Batch

```matlab
report = kssolv.modeling.BatchModeler.run(models, requests, ...
    progressFcn = @(done, total)fprintf("%d/%d\n", done, total), ...
    cancelFcn = @()false);
```

Each item receives its own model copy and response. Failure in one item is
reported in that entry and does not mutate another session.

## Recovery

```matlab
entries = kssolv.modeling.provenance.RecoveryJournal.scan();
valid = entries([entries.valid]);
snapshot = kssolv.modeling.provenance.RecoveryJournal.load(valid(1).path);
model = snapshot.model;
```

Recovery refuses unreadable files, unknown schema, document mismatches and
hash mismatches. A corrupt snapshot is retained for diagnosis rather than
silently replacing project data.

