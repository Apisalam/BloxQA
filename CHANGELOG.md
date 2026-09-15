# Changelog

All notable changes to BloxQA are documented here.

## 0.2.0-dev — One-click Project Initialization

### Added

- Missing, healthy, and incomplete/corrupt project states in the plugin panel.
- `Initialize BloxQA` onboarding action and safe repair action.
- Embedded per-place runtime template with the verified spawn and respawn starter tests.
- BloxQA ownership, schema version, and runtime version metadata.
- Idempotent setup and development-only owned-runtime cleanup support.

### Packaging

- Added the versioned root-Script package `BloxQAPlugin_0_2_0_dev` without replacing the frozen `BloxQAPlugin_0_1_0` rollback release.

## 0.1.0 — Developer Preview

### Added

- Studio toolbar and dockable BloxQA panel.
- Individual and sequential visible-test execution.
- Standardized test metadata and dynamic discovery.
- Registry validation, duplicate-ID diagnostics, and category filtering.
- PASS/FAIL results with durations and error messages.
- Local bounded result history through plugin settings.
- `TestContext` helpers and a discovery-safe authoring template.
- Player spawn and player respawn gameplay tests.
- Semantic version metadata and a Studio-side release builder.

### Fixed

- Replaced the original Model-wrapped, place-coupled plugin release with a root Script containing all plugin startup dependencies.
- Removed blocking global-plugin startup requirements on objects that exist only in the development place.
- Added diagnostics for missing or incomplete per-place runtime installations.

### Known limitations

- This is a local developer preview, not a Creator Store release.
- The public source export does not yet include a one-click packaged plugin artifact.
- Plugin-setting persistence depends on the installed Local Plugin identity.

