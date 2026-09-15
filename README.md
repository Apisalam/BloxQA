# BloxQA

Automated QA and gameplay testing for Roblox Studio.

> **Developer preview — v0.2.0-dev.** BloxQA is an early local tool, not a published Creator Store plugin or production test platform. The frozen v0.1.0 package remains the rollback release.

## Overview

BloxQA is a Roblox Studio plugin and per-place test runtime for repeatable gameplay checks. It discovers valid test modules, launches isolated Studio play-mode sessions, executes tests through a server harness, and returns structured PASS/FAIL results to a dockable panel.

The project was built iteratively as a personal QA automation project using AI-assisted development workflows. Its focus is practical testing, debugging, plugin APIs, defensive error handling, and keeping test definitions separate from the user interface.

## Why BloxQA exists

Gameplay checks such as “did the player spawn correctly?” are easy to repeat manually and easy to forget. BloxQA turns those checks into small Luau modules that can be rerun from Studio while keeping failures, durations, discovery warnings, and recent results visible to the developer.

## Implemented features

- Roblox Studio toolbar button and `DockWidgetPluginGui` panel
- Individual test execution and sequential “Run All visible tests”
- Dynamic discovery of direct-child ModuleScripts whose names end in `Test`
- Required metadata validation and duplicate-ID diagnostics
- Dynamic category filters; filtered runs execute only visible tests
- Studio play-mode execution through `StudioTestService`
- Server-side harness and structured PASS/FAIL reports with durations and errors
- Minimal `TestContext` helpers for waiting, assertions, failure messages, logging, and player lookup
- Plugin-side watchdogs and malformed-result/runtime error handling
- Bounded history of 20 results using plugin settings; the panel shows the five newest entries
- Semantic version module and local release builder
- Self-contained global plugin startup with clear diagnostics when a place runtime is absent
- One-click, idempotent per-place initialization with ownership/schema metadata
- Safe missing, healthy, and incomplete/corrupt project detection

## How it works

```mermaid
flowchart TD
    A[Studio toolbar and dock panel] --> B[Plugin TestRegistry]
    B --> C[Discovered GameplayTests]
    A --> D[Plugin StudioTestController]
    D -->|ExecutePlayModeAsync| E[StudioTestService play session]
    E --> F[BloxQAGameplayTestServer]
    F --> G[Runtime TestRegistry]
    G --> H[TestContext and selected gameplay test]
    H --> I[TestRunner]
    I -->|EndTest structured report| D
    D --> J[Panel results and HistoryStore]
```

The installed plugin contains everything required to start its UI globally and an embedded template for installing the per-place runtime. Actual gameplay execution remains per-place, but v0.2.0-dev can create the runtime, starter tests, and server harness from the onboarding panel.

See [Architecture](docs/architecture.md) for component responsibilities and failure handling.

## Example test

This is the real authoring template shipped with the project:

```luau
return {
    id = "MyTest",
    name = "My Test",
    category = "Gameplay",
    description = "Describe what this verifies.",
    timeout = 10,

    run = function(ctx)
        ctx:log("Starting My Test")

        local player = ctx:getPlayer()
        ctx:expect(player ~= nil, "No Player joined before the timeout")

        -- Add assertions here.
        return true
    end,
}
```

Copy `examples/ExampleTestTemplate.luau` into the place's `ReplicatedStorage.BloxQA.GameplayTests` folder, rename it so the ModuleScript name ends in `Test`, and give it a unique ID. See [Development and testing](docs/development.md).

## Installation and usage

BloxQA currently uses a source-based local installation workflow:

1. Build or update the root-Script package and save that root using **Plugins → Save as Local Plugin**.
2. Restart Studio, open the BloxQA panel, and confirm version `0.2.0-dev` appears.
3. In a place without BloxQA, click **Initialize BloxQA** once.
4. Run one discovered test, choose a category filter, or run all currently visible tests.

Exact instance mappings, safety behavior, and replacement steps are in [Installation](docs/installation.md).

## Repository structure

```text
BloxQA/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── src/
│   ├── plugin/              # Global Studio plugin and embedded modules
│   ├── runtime/             # Per-place runner, context, registry and harness
│   └── tests/gameplay/      # Verified spawn and respawn tests
├── examples/                # Discovery-safe authoring template
├── tools/                   # Studio-side local release builder
├── docs/
│   ├── installation.md
│   ├── architecture.md
│   ├── development.md
│   ├── github.md
│   └── screenshots.md
└── assets/screenshots/      # Repository images to capture in Studio
```

## Current status

Version `0.2.0-dev` initializes two gameplay starter tests:

- **Player Spawn Test** verifies that a player receives a live Character with a Humanoid and HumanoidRootPart.
- **Player Respawn Test** kills the initial Humanoid and verifies that a distinct, live Character appears.

Both tests were verified in the BloxQA development place. This repository does not claim CI, multiplayer, device simulation, input automation, cloud reporting, or Creator Store distribution.

## Limitations and roadmap

Current limitations:

- Studio-only; the server harness exits outside Studio.
- Gameplay tests run one at a time in separate play-mode sessions.
- The runtime and server harness are installed in each tested place by the plugin and remain place-owned data.
- Tests execute through the server harness; client input automation is not implemented.
- History is local to the installed plugin identity and limited to 20 lightweight entries.
- The current release is still a local Studio package, not a Creator Store distribution.

Reasonable next steps are a reproducible package/export workflow, automated Luau checks, a documented compatibility matrix, and additional non-input gameplay assertions.

## Development

The code intentionally keeps the plugin UI, discovery, execution controller, runner, and test definitions modular. Changes should preserve the structured report contract and verify both normal play and Studio test sessions.

See [Development and testing](docs/development.md) and [Screenshot checklist](docs/screenshots.md).

## License

BloxQA is available under the [MIT License](LICENSE).

