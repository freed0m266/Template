# Template

<!-- template-description -->
iOS app template with a modular SwiftUI architecture, managed with Tuist.

<!-- template-only:start -->
## Quick start

After cloning, bootstrap a fresh project in one command:

```bash
./setup.sh MyProjectName
```

This will:

1. Rename `Template` → `MyProjectName` across files, directories, and the project root.
2. Strip the template-only sections out of the docs (see `scripts/finalize_docs.sh`).
3. Run `tuist install` and `tuist generate`.
4. Remove bootstrap artefacts (the rename and doc-finalize scripts, the template's `.git`, and
   `setup.sh` itself).

Once it finishes, initialize fresh source control:

```bash
cd ../MyProjectName
git init && git add . && git commit -m "🎉 Create a project"
open MyProjectName.xcworkspace
```

`ProjectName` must start with a letter and contain only letters and digits (e.g. `Keybo`, `WidgetCoin`).
<!-- template-only:end -->

## Environments

Two Tuist environments select the bundle ID, home-screen display name, and app icon. They are resolved
at `tuist generate` time from the `TUIST_ENVIRONMENT` env-var:

- **Testing** (default) — a sandboxed `.test` build: `Template TEST` on the home screen, a recolored
  `AppIcon-test`, and a `.test`-suffixed bundle ID, so it installs *alongside* a production build.
  Everyday `tuist generate && Run` gives you this.
- **Production** — the shippable identifiers. **A production archive MUST regenerate with the env-var:**

  ```bash
  TUIST_ENVIRONMENT=Production tuist generate
  ```

  Without it, the workspace bakes in `.test` identifiers and any archive from it is a TEST build. See
  [ADR 0001](docs/adr/0001-tuist-environments-default-testing.md). The Apple team ID is a placeholder
  (`TeamID.placeholder`) — set it in `Tuist/ProjectDescriptionHelpers/TeamID.swift` for a real project.

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) — project generation
- [Mint](https://github.com/yonaskolb/Mint) — SwiftLint via build phase
- [Codex CLI](https://github.com/openai/codex) — the `/task` closing review runs `codex review --uncommitted` on the staged diff

```bash
# Install Tuist if you don't have it
curl -Ls https://install.tuist.io | bash

# Install build tools (SwiftLint)
mint bootstrap
```

## Modules

| Module | What it is |
| --- | --- |
| `Template/` | Main app target — entry point, `AppDelegate`, `ContentView` |
| `TemplateCore/` | Shared framework — DI container, `BaseViewModel`, `Logger`, Foundation extensions, `NetworkService` |
| `TemplateUI/` | Design system — reusable components and view extensions |
| `TemplateResources/` | Localization and the generated `L10n` alias |
| `TemplateTesting/` | Snapshot helpers (`AssertSnapshot`) |
| `Features/` | Independent feature frameworks, one per screen |
| `tasks/` | Implementation roadmap — numbered task specs (+ a local, git-ignored dashboard) |
| `docs/adr/` | Architecture Decision Records |
| `scripts/` | Helper scripts (see below) |
| `Tuist/` | Build system configuration — environments and per-target factories |

Directory contents inside a module change often; `ls` is the source of truth, not this table.

Scripts: `new_feature.sh` (scaffold a `Features/<Name>/` from the feature template),
`generate_dashboard.py` (Kanban board of the task files), `clean_worktrees.sh` (remove stale Claude Code
worktrees), `delete_snapshot_references.sh` (delete snapshot reference PNGs to force a re-record).

## Architecture

MVVM with UseCases and a Repository layer, protocol-first throughout:

```
View → ViewModel → UseCase → Repository → Service (API)
```

The conventions — layer boundaries, DI wiring, feature pattern, naming, style, snapshot setup — live in
[CLAUDE.md](CLAUDE.md), which is also the guide coding agents read (`AGENTS.md` symlinks to it).

## Adding a Feature

```bash
./scripts/new_feature.sh FeatureName
tuist generate
```

## Tasks and the `/task` command

`tasks/` holds numbered task specs — see [`tasks/README.md`](tasks/README.md) for the file convention.

`/task <number>` is a **user-level** command, not checked into this repo — it lives in
`~/.claude/commands/task.md` for Claude and `~/.codex/skills/task/` for Codex, so a fresh clone does not
get it. It picks up the task, branches off `main`, implements it, runs the closing review on the staged
diff, and marks the task Done. It never commits — staging is intentional, you write the commit message.
`--skip-review` skips the review step, for purely mechanical scaffolding.

The closing review is **cross-model**: driven from Claude it runs Codex (`codex review --uncommitted`);
driven from Codex it runs Claude (`claude -p`) — the reviewer is always the other model.

Run `python3 scripts/generate_dashboard.py` for a Kanban board of the task files. The rendered
`tasks/dashboard.html` is local and git-ignored, so regenerate it whenever you want (`--serve` for a
live board with drag-and-drop status changes written back into the `.md` files).

## Dependencies

Declared in [`Tuist/Package.swift`](Tuist/Package.swift); each is wired to exactly one target in
`Tuist/ProjectDescriptionHelpers/Targets/`.

| Package | Used by | For |
| --- | --- | --- |
| [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) | `TemplateCore` | Logging |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | `TemplateTesting` | Snapshot tests |
