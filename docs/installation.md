# Installation

BloxQA v0.1.0 is an early source-distributed developer preview. Installation has two independent parts: a global Local Plugin and a runtime added to every place that will execute tests.

## 1. Assemble the global plugin

In Roblox Studio, create this hierarchy in a development place:

```text
BloxQAPlugin [Script]
└── Modules [Folder]
    ├── PluginMain [ModuleScript]
    ├── HistoryStore [ModuleScript]
    ├── Version [ModuleScript]
    ├── TestRegistry [ModuleScript]
    └── StudioTestController [ModuleScript]
```

Copy sources from `src/plugin` into the matching instances. The root Script source comes from `BloxQAPlugin.server.luau`.

1. Select the root `BloxQAPlugin` Script—not the Modules folder or a wrapper Model.
2. Choose **Plugins → Save as Local Plugin**.
3. Name it `BloxQA`.
4. Close every Studio window and restart Studio.
5. Open a new Baseplate and confirm the BloxQA toolbar and panel appear with version `0.1.0`.

The plugin should load even though a new Baseplate has no runtime. Registry Diagnostics will explain that tests cannot run there yet.

## 2. Install the per-place runtime

Create this hierarchy in each place to be tested:

```text
ReplicatedStorage
└── BloxQA [Folder]
    ├── TestRunner [ModuleScript]
    ├── StudioTestController [ModuleScript]
    ├── Version [ModuleScript]
    ├── TestRegistry [ModuleScript]
    ├── TestContext [ModuleScript]
    └── GameplayTests [Folder]
        ├── CharacterTestUtils [ModuleScript]
        ├── PlayerSpawnTest [ModuleScript]
        └── PlayerRespawnTest [ModuleScript]

ServerScriptService
└── BloxQAGameplayTestServer [Script]
```

Copy matching files from `src/runtime` and `src/tests/gameplay`. `BloxQAGameplayTestServer.server.luau` belongs in ServerScriptService; the other runtime modules belong in `ReplicatedStorage.BloxQA`.

## Use

1. Click **Plugins → BloxQA → BloxQA** to toggle the panel.
2. Check Registry Diagnostics for valid and invalid counts.
3. Click a test's Run button, or select a dynamic category filter.
4. Click Run All Visible Tests (or the category-specific label) to execute visible valid tests sequentially.
5. Expand Recent Runs to view local history.

## Replace a local installation

1. Open **Plugins → Manage Plugins** and disable or uninstall the old BloxQA plugin.
2. Save the new root Script as a Local Plugin and confirm replacement.
3. Restart every Studio window.
4. Verify the displayed version in a clean Baseplate and again in a place with the runtime.

## Current packaging limitation

This repository export contains reviewed source, not a generated `.rbxmx`/Creator Store package. Producing and validating a reproducible downloadable artifact is recommended before inviting non-developer users to install BloxQA.
