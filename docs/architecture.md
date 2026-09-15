# Architecture

BloxQA is split into a global Studio plugin and a runtime installed in each place under test. This separation lets the toolbar and panel load in any place without pretending that gameplay tests can run where the runtime is absent.

## Execution flow

```mermaid
sequenceDiagram
    participant Developer
    participant UI as PluginMain
    participant Registry as Plugin TestRegistry
    participant Controller as Plugin StudioTestController
    participant STS as StudioTestService
    participant Server as BloxQAGameplayTestServer
    participant Runner as TestRunner
    participant Test as Gameplay test

    Developer->>UI: Run one / Run all visible
    UI->>Registry: Discover and validate GameplayTests
    UI->>Controller: run(testId, metadata)
    Controller->>STS: ExecutePlayModeAsync or ExecuteMultiplayerTestAsync
    STS->>Server: Start isolated server and requested clients
    Server->>Registry: Resolve testId again in play mode
    Server->>Test: Create TestContext and call run(ctx)
    Test-->>Runner: true or false/message, or error
    Runner-->>Server: Structured report
    Server->>STS: EndTest(report)
    STS-->>Controller: Structured report
    Controller-->>UI: Result
    UI->>UI: Render result and update history
```

## Global plugin

`src/plugin/BloxQAPlugin.server.luau` is the executable plugin root. It receives Roblox's global `plugin` object and starts `PluginMain` inside `pcall`.

`PluginMain` creates the toolbar, button, and dock widget. It discovers tests from the current place, renders category filters and diagnostics, runs tests sequentially, normalizes reports, and catches unexpected errors. It does not duplicate play-session execution logic.

The plugin embeds its own copies of:

- `Version` for display and release identity.
- `TestRegistry` for safe edit-time discovery.
- `StudioTestController` for the `StudioTestService` boundary.
- `HistoryStore` for bounded plugin-setting persistence.
- `ProjectInitializer` for project-state inspection, idempotent setup, and conservative repair.
- `RuntimeTemplate` for the self-contained per-place runtime and starter-test sources.

If the current place has no BloxQA runtime, the toolbar and panel show onboarding instead of run controls. Initialization materializes only the embedded BloxQA runtime under `ReplicatedStorage.BloxQA`, `ServerScriptService.BloxQAGameplayTestServer`, and `StarterPlayer.StarterPlayerScripts.BloxQAMultiplayerTestClient`. Every created object is marked with `BloxQAOwned`, `BloxQASchemaVersion`, and `BloxQARuntimeVersion` attributes. Unowned or incompatible objects are diagnosed and never silently replaced.

## Per-place runtime

`TestRegistry` scans only direct children of `ReplicatedStorage.BloxQA.GameplayTests` whose ModuleScript names end in `Test`. It validates metadata, catches module load failures, rejects duplicate IDs, and sorts valid definitions by category, name, then ID. Invalid tests do not prevent valid tests from running.

`StudioTestController` uses normalized metadata to start either a single-player session or one real Studio multiplayer session with 2–8 clients. Protocol version `2` carries the selected test ID, timeout, mode, and expected player count.

`BloxQAGameplayTestServer` runs only in Studio. It validates the protocol and metadata, discovers the selected definition again, creates `TestContext`, applies a hard deadline, delegates execution to `TestRunner`, and ends the Studio test exactly once with a structured report.

`MultiplayerCoordinator` provides deterministic participants, readiness waits, and leave coordination. The small client harness waits for a test-only `RemoteEvent` and uses the documented Studio-only `CanLeaveTest`/`LeaveTest` methods. No bridge is created during normal play.

`TestRunner` executes the supplied tests sequentially under `pcall`, measures elapsed time with `os.clock`, and returns totals plus result records.

## Result contract

The runner returns:

```luau
{
    total = number,
    passed = number,
    failed = number,
    results = {
        {
            name = string,
            status = "PASS" or "FAIL",
            passed = boolean,
            errorMessage = string?,
            durationMs = number,
            mode = "singleplayer" or "multiplayer",
            expectedPlayers = number,
            playerCount = number,
        },
    },
}
```

The plugin validates incoming reports before displaying them. Service errors, malformed reports, missing duration/pass fields, controller errors, and watchdog timeouts are converted into readable failed results.

## History

`HistoryStore` records the test ID, display name, PASS/FAIL status, duration, timestamp, and optional error. It keeps at most 20 entries and uses `Plugin:GetSetting`/`Plugin:SetSetting`. Persistence failures are caught; in-memory history remains usable for the current plugin session.
