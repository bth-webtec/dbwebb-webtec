# CLAUDE.md — dbwebb-webtec

CLI (`@dbwebb/webtec`, published to npm) used by students and staff on the webtec course to
check that a student's repo contains what's expected for each kmom (paths, git tag in the right
semver range, lab points, report text, eslint). Entry point `bin/dbw-webtec.bash` dispatches to
`bin/dbw-check.bash`, `bin/dbw-help.bash`, etc.

## Publishing

Publishing to npm is automatic via `.github/workflows/npm-publish.yml`, triggered by any pushed
tag matching `v*.*.*`. To ship a release:

1. Bump the version: `npm version <patch|minor|major>`. This runs the `version` npm script
   (`scripts/sync-version.js`), which syncs the `VERSION` exported by `bin/dbw-webtec.bash` with
   `package.json` so the CLI can never report a stale version — then commits and tags
   `vX.Y.Z` automatically.
2. Push both: `git push --follow-tags` (or `git push && git push --tags`).
3. The `npm-publish.yml` workflow checks the pushed tag matches `package.json`'s version, then
   publishes.

The workflow authenticates via npm **Trusted Publishing** (OIDC) — no `NPM_TOKEN` secret is
stored or needs rotating. This mirrors the setup used for `@dbwebb/tui`
(`~/g/repo/node-tui`, documented in that repo's `DEVELOPMENT.md`), adapted from GitLab CI/CD to
GitHub Actions. One-time setup done on npmjs.com, under the `@dbwebb/webtec` package's
**Settings → Trusted Publisher**:

- **Publisher**: GitHub Actions
- **Organization or user**: `bth-webtec`
- **Repository**: `dbwebb-webtec`
- **Workflow filename**: `npm-publish.yml`
- **Environment name**: (left blank — no GitHub Actions environment used)
- **Allow `npm publish`**: checked (required — the workflow calls `npm publish` directly, not
  the two-step `npm stage publish` flow, which is npm's more restrictive default)

## Tag-pushed check (kmom_check_tag_pushed)

`bin/dbw-check.bash` checks that a student's repo has a git tag in the right semver range for
each kmom (`kmom_check_tag`) **and** that the tag was actually pushed to `origin`
(`kmom_check_tag_pushed`, added because a student had a tag that existed locally but was never
pushed with `git push --tags` — the check passed locally but grading on GitHub saw no tag at
all). `getRemoteTags` caches one `git ls-remote --tags origin` call per script invocation so a
chained kmom check (e.g. `kmom06` recursively checking `kmom05` → ... → `labbmiljo`) only hits
the network once.

This also runs fine inside a student's own `.github/workflows/check.yml` (in their kmom repo,
not this one): `actions/checkout@v4` with `fetch-depth: 0` fetches tags locally, and
`actions/checkout`'s embedded `GITHUB_TOKEN` auth header covers the `git ls-remote` network call
too, so no extra permissions or secrets are needed there.
