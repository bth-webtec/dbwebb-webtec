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

## Testing

`test/*.bats` (bats-core, run via `npm test` → `bats test`) covers the CLI scripts in `bin/`:
unit tests for `dbw-check.bash`'s pure helpers (`getSemanticVersion`, `hasGitTagBetween`,
`check_paths`, `kmom_check_tag`, `kmom_check_tag_pushed`), sourced with real temp git repos/tags,
plus CLI-level dispatch/usage/exit-code tests for both `dbw-webtec.bash` and `dbw-check.bash`.
`dbw-check.bash` has a `if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi` guard at the
bottom specifically so the test suite can `source` it to unit-test the helpers without triggering
a full CLI run — keep that guard if the file is restructured.

`test/dbw-webtec.bats` includes a regression test for the `realpath`-on-macOS bug (see below):
it invokes the CLI through an npm-style `.bin` symlink with `realpath` stripped from `PATH`
(`test/fixtures/no-realpath-path.bash` builds that PATH) and asserts it still finds its sibling
scripts. Verified this actually catches the bug by running it against the pre-fix commit, where
it fails with the exact reported error.

Enforcement, so a regression can't slip through unnoticed:
- **Locally**: a husky pre-push hook (`.husky/pre-push`, wired via `"prepare": "husky"` so it's
  set up automatically on `npm install`) runs `npm test` before every `git push` and blocks the
  push on failure.
- **CI**: `.github/workflows/test.yml` runs `npm test` on every push/PR to `main` — separate
  from the tag-triggered `npm-publish.yml`, as a second line of defense (e.g. against
  `git push --no-verify`).

## realpath / macOS portability

`bin/dbw-webtec.bash` and `bin/dbw-check.bash` used to resolve their own script directory with
`realpath "$0"`. macOS doesn't ship `realpath` by default (no GNU coreutils), so this broke the
CLI there entirely (`realpath: command not found`, then `check`/`help` dispatch failing with
"No such file or directory"). Both scripts now resolve their real path with a manual
symlink-following loop (`readlink` + `cd -P` + `pwd`) instead — still needed (not just
`dirname "$0"`) because npm installs the CLI as a symlink in `node_modules/.bin`. See the
regression test above before reintroducing any dependency on `realpath`.

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
