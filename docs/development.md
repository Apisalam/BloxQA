# Development and testing

## Test definition format

Every discoverable gameplay test must return a table with these fields:

```luau
return {
    id = "UniqueStableId",
    name = "Readable Test Name",
    category = "Gameplay",
    description = "What this test verifies.",
    timeout = 10,

    run = function(ctx)
        -- Assertions or a boolean result.
        return true
    end,
}
```

`id`, `name`, `category`, and `description` must be non-empty strings. `timeout` must be a positive number and `run` must be a function. IDs must be unique within the discovered container.

## Adding a test

1. Duplicate `examples/ExampleTestTemplate.luau` as a ModuleScript under `ReplicatedStorage.BloxQA.GameplayTests`.
2. Rename the ModuleScript so its name ends in `Test`; this suffix enables discovery.
3. Replace the ID, name, category, description, timeout, and test body.
4. Open or refresh the BloxQA panel and check Registry Diagnostics.
5. Run the test individually before including it in a filtered or all-visible run.

The template itself ends in `Template`, so it is intentionally ignored.

## Supported TestContext API

- `ctx.testId`, `ctx.testName`, `ctx.timeout`, and `ctx.timeoutSeconds` expose current metadata/execution arguments.
- `ctx:waitFor(predicate, timeoutSeconds?, intervalSeconds?)` polls a protected predicate and returns its first truthy value or `nil`.
- `ctx:getPlayer(timeoutSeconds?)` waits for the first player in the play session.
- `ctx:expect(condition, message?)` throws a test failure when the condition is false.
- `ctx:fail(message?)` throws an explicit test failure.
- `ctx:log(message)` writes a test-prefixed Studio Output message.

A test may also return `false, "message"`. An uncaught error is converted into a failed result by `TestRunner`.

## Discovery behavior

Discovery is deliberately narrow and deterministic:

- Only direct-child ModuleScripts are considered.
- The ModuleScript name must end in `Test`.
- Candidates are loaded through `pcall`.
- Invalid definitions and duplicate IDs become diagnostics.
- Valid tests are sorted by category, display name, and ID.
- Category buttons are generated from discovered metadata, not hardcoded values.

Run All uses the currently visible list. Selecting a category therefore runs only tests in that category, sequentially, and continues after failures.

## Manual verification checklist

Before publishing a release:

1. Confirm the global plugin loads in a place with no BloxQA runtime and shows a useful diagnostic.
2. Confirm the plugin discovers Player Spawn and Player Respawn in the development place.
3. Run each test individually and verify status, duration, and failure text rendering.
4. Run all visible tests and verify sequential progress and totals.
5. Verify category filtering changes the visible list and Run All label.
6. Temporarily introduce malformed metadata and confirm valid tests remain runnable; remove it afterward.
7. Confirm history updates and controls recover after a failed run.
8. Start an ordinary manual play session and confirm the harness exits when no BloxQA protocol arguments are present.
9. Confirm no unrelated Workspace instances changed.

AI-assisted workflows were used during development. Review generated changes against the source contracts above and verify behavior in Studio rather than treating generated code as proof of correctness.
