# Release Process

This page documents how to ship a new version of SPSCleanDependencies. The process is centered on a single source of truth — the `ModuleVersion` field of `SPSCleanDependencies.Common.psd1` — and a `v*` git tag that triggers the GitHub release workflow.

## Versioning policy

SPSCleanDependencies follows [Semantic Versioning 2.0](https://semver.org/spec/v2.0.0.html).

| Bump | When |
|---|---|
| MAJOR (X.0.0) | Breaking change in the package layout, the results JSON schema, or a public module function signature. |
| MINOR (X.Y.0) | New backward-compatible feature (new cleanup branch, new public function, new optional parameter). |
| PATCH (X.Y.Z) | Bug fix or documentation-only change. |

## Release checklist

### 1. Bump the version

Edit **one** value in `src/Modules/SPSCleanDependencies.Common/SPSCleanDependencies.Common.psd1`:

```powershell
ModuleVersion = '1.3.0'   # was '1.2.0'
```

This single change propagates automatically to:

- The script banner (`$SPSCleanDependenciesVersion` is read from `(Get-Module SPSCleanDependencies.Common).Version`)
- The `Get-Module SPSCleanDependencies.Common` version surfaced to users

### 2. Update `CHANGELOG.md`

Add a dated section for the version being released, following [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

### 3. Replace `RELEASE-NOTES.md`

`RELEASE-NOTES.md` is used **verbatim** as the body of the GitHub Release. It must contain **only** the section of the version being released (no stacked history).

### 4. Validate locally

```powershell
Import-Module .\src\Modules\SPSCleanDependencies.Common\SPSCleanDependencies.Common.psd1 -Force
(Get-Module SPSCleanDependencies.Common).Version    # should match the bumped version
Invoke-Pester -Path .\tests
Invoke-ScriptAnalyzer -Path .\src -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

### 5. Commit on a release branch

```bash
git checkout -b Release/1.3.0
git add -A
git commit -m "release: v1.3.0"
git push -u origin Release/1.3.0
```

Test the branch ZIP on a real farm first, then open a Pull Request, review, and merge to `main`.

### 6. Tag from `main`

```bash
git checkout main
git pull
git tag v1.3.0
git push origin v1.3.0
```

The `.github/workflows/release.yml` workflow runs automatically. It:

1. Packages the **contents** of `src/` into `SPSCleanDependencies-v1.3.0.zip` (the archive extracts straight to `SPSCleanDependencies.ps1` and `Modules\`, with no `src/` wrapper).
2. Publishes a GitHub Release using `RELEASE-NOTES.md` as the body.
3. Attaches the ZIP and `LICENSE` to the release.

### 7. Verify

- **Releases**: <https://github.com/luigilink/SPSCleanDependencies/releases> — the new release is listed with the expected body and ZIP.
- **Actions**: <https://github.com/luigilink/SPSCleanDependencies/actions> — `release.yml` and `pester.yml` ran green.
- **Wiki**: <https://github.com/luigilink/SPSCleanDependencies/wiki> — `wiki.yml` synced any `wiki/` changes pushed in the same release.

## Undoing a release

If you tagged too early:

```bash
git tag -d v1.3.0
git push origin --delete v1.3.0
```

Then delete the auto-created Release on GitHub, fix what needs fixing, commit, and re-tag from the new HEAD.

> ⚠️ **Don't move a published tag** that has been live for more than a few minutes. Prefer publishing a `vX.Y.(Z+1)` patch release instead of rewriting `vX.Y.Z`.

## See also

- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning 2.0](https://semver.org/spec/v2.0.0.html)
- [Getting Started](Getting-Started)
- [Usage](Usage)
