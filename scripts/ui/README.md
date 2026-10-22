# Browser UI regression tests

`tests/` exercises MATLAB browser assets and their client event contracts. These
tests do not require Docker, MATLAB, or Java/JVM. Install the frontend dependencies
first (`pnpm --dir frontend install --frozen-lockfile`), then run from the repository
root:

```sh
node --test scripts/ui/tests/*.cjs
```

The equivalent frontend command is `pnpm --dir frontend test:browser`. Portal and
admin page tests remain alongside the deployment tests in `scripts/k8s/tests/`:

```sh
node --test scripts/k8s/tests/*.cjs
```

Production MATLAB browser assets live in `+kssolv/+ui/resources/browser/`;
production portal/admin pages live in `server/portal/public/` and
`server/admin/public/`. See [the directory guide](../../docs/development-layout.md).
