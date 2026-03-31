# TICKET-018: Publish apfel via Homebrew tap

**Status:** Open
**Priority:** P2
**Type:** Distribution / packaging

---

## Goal

Make `apfel` installable with:

```bash
brew install Arthur-Ficial/tap/apfel
```

## Exact Path

1. Create a tap repository:
   - `Arthur-Ficial/homebrew-tap`
   - Formula path: `Formula/apfel.rb`

2. Tag stable releases in `Arthur-Ficial/apfel`:
   - Example: `v0.6.4`
   - Use GitHub release tarballs as the formula source URL

3. Keep Homebrew builds deterministic:
   - Do **not** call `make install` from the formula
   - Build directly with `swift build -c release`
   - Install with `bin.install ".build/release/apfel"`

4. Write the formula with:
   - `desc`
   - `homepage`
   - `url`
   - `sha256`
   - `license`
   - macOS-only constraints
   - lightweight `test do`

5. Validate locally:
   - `brew tap Arthur-Ficial/tap`
   - `brew install --build-from-source Arthur-Ficial/tap/apfel`
   - `brew test Arthur-Ficial/tap/apfel`
   - `brew audit --strict Arthur-Ficial/tap/apfel`

6. Add bottles later:
   - GitHub Actions in the tap repo
   - `brew test-bot` workflow

## Repo-Specific Blockers

- `Makefile` auto-bumps version and edits tracked files during `build/install`
- Homebrew formula installs must not mutate the source tree
- Release tarballs must contain the correct committed `Sources/BuildInfo.swift`

## Suggested Follow-Up

- Add a dedicated non-mutating packaging target for distribution workflows
- Scaffold `Formula/apfel.rb`
- Add a release checklist for tag -> SHA update -> brew audit -> bottle publish
