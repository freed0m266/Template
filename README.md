# Template

iOS app template with a modular SwiftUI architecture, managed with Tuist.

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) (for project generation)
- [Mint](https://github.com/yonaskolb/Mint) (for SwiftLint via build phase)

## Getting Started

```bash
# Install Tuist if you don't have it
curl -Ls https://install.tuist.io | bash

# Install build tools (SwiftLint)
mint bootstrap

# Resolve and generate the Xcode project
tuist install
tuist generate

# Open in Xcode
open Template.xcworkspace
```

## Project Structure

```
Template/
├── Template/                       # Main app target (entry point + ContentView)
│   ├── Sources/
│   │   ├── App/                    # @main + AppDelegate (logger setup)
│   │   └── Views/                  # ContentView (top-level screen)
│   └── Resources/                  # Asset catalog
├── TemplateCore/                   # Shared framework (DI, models, services)
│   └── Sources/
│       ├── Dependencies/           # AppDependency container
│       ├── Extensions/             # Foundation extensions
│       ├── Services/               # NetworkService and friends
│       └── Shared/                 # BaseViewModel, Logger
├── TemplateUI/                     # Design system (View+Extensions, Icon)
├── TemplateResources/              # Localization (L10n alias)
├── TemplateTesting/                # AssertSnapshot helper
├── Features/                       # Independent feature frameworks
│   └── Example/
│       ├── Sources/                # View, ViewModel, Dependencies
│       ├── Testing/                # Mock ViewModel (DEBUG)
│       └── Tests/                  # Snapshot tests
└── Tuist/                          # Build system configuration
    └── ProjectDescriptionHelpers/
```

## Architecture

The template follows **MVVM** with **UseCases** and a **Repository** layer:

```
View → ViewModel → UseCase → Repository → Service (API)
```

- Every ViewModel, UseCase, Repository, and Service is backed by a protocol
- Dependencies are injected via a global `AppDependency` container
- Each feature defines its own `*Dependencies` struct + `AppDependency` extension
- Views are generic over their ViewModel protocols

## Adding a Feature

1. Create `Features/{Name}/{Sources,Testing,Tests}/`
2. Add `{Name}View.swift`, `{Name}ViewModel.swift`, `{Name}Dependencies.swift`
3. Add `{Name}ViewModelMock.swift` under `Testing/`
4. Add `{Name}Snapshots.swift` under `Tests/`
5. Register the feature in `Tuist/ProjectDescriptionHelpers/Targets/Features/{Name}.swift`
6. Add it to `features` in `Project.swift` and to the app's dependency list in `Targets/App.swift`
7. Run `tuist generate`

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — Logging
- [BaseKitX](https://github.com/freed0m266/BaseKitX) — Foundation utilities
- [ACKategories](https://github.com/AckeeCZ/ACKategories) — Common helpers
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — Snapshot tests
