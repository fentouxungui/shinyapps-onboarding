# Skill version gate (mandatory)

## Rule

Before any workflow-related operation, obtain and verify the latest
`shinyapps-onboarding` skill. Do not start from a loaded/imported snapshot, a
local branch, or memory until this gate passes.

Applies to:

* creating a new per-app `.github/workflows/build-app-bundle.yml`;
* upgrading, patching, renaming, or reviewing an existing workflow;
* changing this skill's workflow template, workflow rules/references, or the
  scripts that generate/validate workflows for an app.

A stale skill is a defect even when the requested edit looks mechanical.

## Canonical source and version

* Repo: <https://github.com/fentouxungui/shinyapps-onboarding>
* Branch: `main`
* Version marker: `VERSION` at the repo root (human-readable, date-based)
* Authoritative version: the canonical `main` commit SHA at verification time
* Workflow template: `assets/build-app-bundle.yml`
* The loaded skill must match the canonical `VERSION`, `SKILL.md`, and
  `assets/build-app-bundle.yml`.

## Preflight

1. **Locate the loaded skill.** Use the app's skill catalog/loader or the path
   the user supplied. Do not scan the host filesystem or assume a clone is the
   copy the agent actually loaded.
2. **Identify its form.** A git checkout (has `.git`) or an imported/copied
   snapshot (no `.git`).
3. **Fetch canonical state.** Get the canonical `main` commit, `VERSION`,
   `SKILL.md` and `assets/build-app-bundle.yml` as described below.
4. **Compare.**
   * Git checkout: `HEAD` must equal `origin/main` and the tree must be clean.
   * Imported copy: `VERSION`, `SKILL.md` SHA-256 and
     `assets/build-app-bundle.yml` SHA-256 must all match canonical `main`.
5. **Update if stale.** A git checkout behind `origin/main` and clean may
   `git pull --ff-only origin main`. An imported copy must be re-imported
   through the application's skill import flow; do not edit it in place.
6. **Reload the instructions.** A file on disk is not enough if the app caches
   the loaded skill. Restart/reload or re-import so the agent is actually using
   the new `SKILL.md`; then re-read `SKILL.md`, `VERSION`,
   `references/release-hardening.md` and `assets/build-app-bundle.yml`.
7. **Record evidence.** In `apps/<id>/NOTES.md` and the PR/reply, record the
   canonical commit SHA, `VERSION`, the loaded path/commit/hash, the date, and
   whether the workflow was generated or patched.

## Commands

### Git checkout

```bash
SKILL_DIR="<loaded skill dir>"
git -C "$SKILL_DIR" fetch origin main
git -C "$SKILL_DIR" rev-parse HEAD
git -C "$SKILL_DIR" rev-parse origin/main
git -C "$SKILL_DIR" status --short
git -C "$SKILL_DIR" show origin/main:VERSION
```

Pass only when `HEAD == origin/main`, the tree is clean, and the loaded
`VERSION` equals the canonical one. If the checkout is dirty or ahead, it is a
development snapshot: stop unless the user explicitly pins that commit and diff,
and record it as not verified latest.

### Imported/copied skill

```bash
git ls-remote https://github.com/fentouxungui/shinyapps-onboarding.git refs/heads/main
curl -fsSL https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/VERSION
curl -fsSL https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/SKILL.md | sha256sum
curl -fsSL https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/assets/build-app-bundle.yml | sha256sum

cat "$SKILL_DIR/VERSION"
sha256sum "$SKILL_DIR/SKILL.md"
sha256sum "$SKILL_DIR/assets/build-app-bundle.yml"
```

If any value differs, the loaded skill is stale. Re-import/reload it through the
app; do not proceed.

### PowerShell

```powershell
$SkillDir = "<loaded skill dir>"
$Canonical = (Invoke-RestMethod `
  https://api.github.com/repos/fentouxungui/shinyapps-onboarding/commits/main).sha
$CanonicalVersion = (Invoke-WebRequest `
  https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/VERSION).Content.Trim()
(Get-FileHash -Algorithm SHA256 "$SkillDir\SKILL.md").Hash
(Get-FileHash -Algorithm SHA256 "$SkillDir\assets\build-app-bundle.yml").Hash
```

For an imported copy, download the canonical raw files to a temp path and compare
the hashes:

```powershell
$Tmp = Join-Path $env:TEMP "shinyapps-onboarding-main"
New-Item -ItemType Directory -Force $Tmp | Out-Null
Invoke-WebRequest `
  https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/SKILL.md `
  -OutFile "$Tmp\SKILL.md"
Invoke-WebRequest `
  https://raw.githubusercontent.com/fentouxungui/shinyapps-onboarding/main/assets/build-app-bundle.yml `
  -OutFile "$Tmp\build-app-bundle.yml"
(Get-FileHash -Algorithm SHA256 "$Tmp\SKILL.md").Hash
(Get-FileHash -Algorithm SHA256 "$Tmp\build-app-bundle.yml").Hash
```

For a git checkout, `git rev-parse HEAD origin/main` is simpler and stronger
than hashing files.

## New workflow

* Complete the gate before feasibility or generation.
* Generate from the verified `assets/build-app-bundle.yml`. Do not copy from
  `examples/` (historical v1 workflows).
* After generation, verify the current tag/release rules, the `-r<abi>` asset
  naming, the smoke test, and the metadata files are present.
* Record the verified skill commit and `VERSION` in the app record and PR.

## Upgrade/modify an existing workflow

* Complete the gate before reading or editing the existing workflow.
* Diff the existing workflow against the verified template; list every missing
  rule (tag canonicalization, attach-only manual runs, `-r<abi>` assets,
  deps/meta/build-info, base/recommended exclusion, smoke test, portable R when
  applicable, standard filename).
* Apply the migration rules from the verified skill (including the workflow
  filename migration, if needed).
* Re-run YAML parsing, `scripts/validate-apps.ps1`, and the smoke test when it
  can run. Record the skill commit and the workflow diff in the app record/PR.
* If the workflow was generated by an older skill, say so in the PR/notes; do
  not silently preserve old behavior.

## Skill maintenance exception

When you are intentionally editing this skill itself, the current branch is the
source of truth. Do not generate app workflows from an uncommitted local template
unless the user explicitly pins that commit/diff and you record it. Bump
`VERSION`, commit, and push to canonical `main`; only then is it the latest for
consumer workflow work.

## Fail closed

If the canonical state cannot be fetched or the loaded copy cannot be verified,
STOP and ask the user. Do not use an old version "temporarily". The only
exception is an explicit user instruction to use a pinned/offline version; record
the pinned commit and state that it is not verified latest.
