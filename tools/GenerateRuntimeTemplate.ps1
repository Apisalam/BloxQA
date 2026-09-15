param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$delimiterOpen = "[========["
$delimiterClose = "]========]"

function Read-Source([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    $source = [System.IO.File]::ReadAllText($path)
    if ($source.Contains($delimiterClose)) {
        throw "Source contains the RuntimeTemplate long-string delimiter: $relativePath"
    }
    return $source.TrimEnd("`r", "`n") + "`n"
}

function Source-Descriptor([string]$name, [string]$className, [string]$relativePath, [int]$indentLevel) {
    $indent = "`t" * $indentLevel
    $childIndent = "`t" * ($indentLevel + 1)
    $source = Read-Source $relativePath
    return @(
        "$indent{",
        "${childIndent}name = `"$name`",",
        "${childIndent}className = `"$className`",",
        "${childIndent}source = $delimiterOpen$source$delimiterClose,",
        "$indent},"
    ) -join "`n"
}

$rootModules = @(
    @{ Name = "TestRunner"; Path = "src/runtime/TestRunner.luau" },
    @{ Name = "TestRegistry"; Path = "src/runtime/TestRegistry.luau" },
    @{ Name = "TestContext"; Path = "src/runtime/TestContext.luau" },
    @{ Name = "MultiplayerCoordinator"; Path = "src/runtime/MultiplayerCoordinator.luau" },
    @{ Name = "StudioTestController"; Path = "src/runtime/StudioTestController.luau" },
    @{ Name = "Version"; Path = "src/runtime/Version.luau" }
)

$tests = @(
    @{ Name = "CharacterTestUtils"; Path = "src/tests/gameplay/CharacterTestUtils.luau" },
    @{ Name = "PlayerSpawnTest"; Path = "src/tests/gameplay/PlayerSpawnTest.luau" },
    @{ Name = "PlayerRespawnTest"; Path = "src/tests/gameplay/PlayerRespawnTest.luau" },
    @{ Name = "TwoPlayerPresenceTest"; Path = "src/tests/multiplayer/TwoPlayerPresenceTest.luau" },
    @{ Name = "PlayerLeaveTest"; Path = "src/tests/multiplayer/PlayerLeaveTest.luau" },
    @{ Name = "ExampleTestTemplate"; Path = "examples/ExampleTestTemplate.luau" }
)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('local RuntimeTemplate = {')
$lines.Add('`truntimeVersion = "0.3.0-dev",'.Replace('`t', "`t"))
$lines.Add('`tschemaVersion = 2,'.Replace('`t', "`t"))
$lines.Add('}')
$lines.Add('')
$lines.Add('RuntimeTemplate.runtimeRoot = {')
$lines.Add('`tname = "BloxQA",'.Replace('`t', "`t"))
$lines.Add('`tclassName = "Folder",'.Replace('`t', "`t"))
$lines.Add('`tchildren = {'.Replace('`t', "`t"))

foreach ($module in $rootModules) {
    $lines.Add((Source-Descriptor $module.Name "ModuleScript" $module.Path 2))
}

$lines.Add("`t`t{")
$lines.Add("`t`t`tname = `"GameplayTests`",")
$lines.Add("`t`t`tclassName = `"Folder`",")
$lines.Add("`t`t`tchildren = {")
foreach ($test in $tests) {
    $lines.Add((Source-Descriptor $test.Name "ModuleScript" $test.Path 4))
}
$lines.Add("`t`t`t},")
$lines.Add("`t`t},")
$lines.Add("`t},")
$lines.Add("}")
$lines.Add("")

$lines.Add('RuntimeTemplate.serverHarness = {')
$lines.Add('`tname = "BloxQAGameplayTestServer",'.Replace('`t', "`t"))
$lines.Add('`tclassName = "Script",'.Replace('`t', "`t"))
$lines.Add('`tdisabled = false,'.Replace('`t', "`t"))
$serverSource = Read-Source "src/runtime/BloxQAGameplayTestServer.server.luau"
$lines.Add("`tsource = $delimiterOpen$serverSource$delimiterClose,")
$lines.Add('}')
$lines.Add('')

$lines.Add('RuntimeTemplate.clientHarness = {')
$lines.Add('`tname = "BloxQAMultiplayerTestClient",'.Replace('`t', "`t"))
$lines.Add('`tclassName = "LocalScript",'.Replace('`t', "`t"))
$lines.Add('`tdisabled = false,'.Replace('`t', "`t"))
$clientSource = Read-Source "src/runtime/BloxQAMultiplayerTestClient.client.luau"
$lines.Add("`tsource = $delimiterOpen$clientSource$delimiterClose,")
$lines.Add('}')
$lines.Add('')
$lines.Add('return RuntimeTemplate')
$lines.Add('')

Write-Output ($lines -join "`n")
