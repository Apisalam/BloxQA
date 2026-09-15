# Installation

BloxQA v0.2.0-dev is an early local developer preview. The global Local Plugin embeds the per-place runtime and installs it through the onboarding panel.

## 1. Assemble the global plugin

In Roblox Studio, create this hierarchy in a development place:

```text
BloxQAPlugin [Script]
└── Modules [Folder]
    ├── PluginMain [ModuleScript]
    ├── HistoryStore [ModuleScript]
    ├── Version [ModuleScript]
    ├── TestRegistry [ModuleScript]
    ├── StudioTestController [ModuleScript]
    ├── ProjectInitializer [ModuleScript]
    └── RuntimeTemplate [ModuleScript]
```

Copy sources from `src/plugin` into the matching instances. The root Script source comes from `BloxQAPlugin.server.luau`.

1. Select the root `BloxQAPlugin` Script—not the Modules folder or a wrapper Model.
2. Choose **Plugins → Save as Local Plugin**.
3. Name it `BloxQA`.
4. Close every Studio window and restart Studio.
5. Open a new Baseplate and confirm the BloxQA toolbar and panel appear with version `0.2.0-dev`.

The plugin should load even though a new Baseplate has no runtime. The panel displays **No BloxQA project detected** and an **Initialize BloxQA** button.

## 2. Initialize a place

1. Open the BloxQA panel in the place to test.
2. Click **Initialize BloxQA**.
3. Confirm the panel refreshes without reopening and discovers Player Spawn Test and Player Respawn Test.

Initialization creates this hierarchy:

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
        ├── ExampleTestTemplate [ModuleScript, ignored by discovery]
        ├── PlayerSpawnTest [ModuleScript]
        └── PlayerRespawnTest [ModuleScript]

ServerScriptService
└── BloxQAGameplayTestServer [Script]
```

The plugin creates only this BloxQA-owned hierarchy. Running initialization again is a no-op. If conflicting or unowned objects already use these names, BloxQA reports the issue and does not replace them. A safe repair is offered only when missing objects can be added without overwriting existing content.

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

This remains a Local Plugin developer-preview workflow, not a Creator Store package. The plugin must be installed from the versioned root Script in Studio; source folders alone are not executable plugin artifacts.

