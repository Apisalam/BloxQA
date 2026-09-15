local RuntimeTemplate = {
	runtimeVersion = "0.2.0-dev",
	schemaVersion = 1,
}

RuntimeTemplate.runtimeRoot = {
	name = "BloxQA",
	className = "Folder",
	children = {
		{
			name = "TestRunner",
			className = "ModuleScript",
			source = [====[local TestRunner = {}

function TestRunner.run(tests)
	local results = {}
	local passedCount = 0

	for _, test in ipairs(tests) do
		local startedAt = os.clock()
		local callSucceeded, outcome, message = pcall(test.run)
		local durationMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))

		local passed = callSucceeded and outcome == true
		local errorMessage = nil

		if not callSucceeded then
			errorMessage = tostring(outcome)
		elseif not passed then
			errorMessage = message or ("Expected true, got " .. tostring(outcome))
		end

		if passed then
			passedCount += 1
		end

		table.insert(results, {
			name = test.name,
			status = passed and "PASS" or "FAIL",
			passed = passed,
			errorMessage = errorMessage,
			durationMs = durationMs,
		})
	end

	return {
		total = #results,
		passed = passedCount,
		failed = #results - passedCount,
		results = results,
	}
end

return TestRunner

]====],
		},
		{
			name = "TestRegistry",
			className = "ModuleScript",
			source = [====[local TestRegistry = {}

local REQUIRED_FIELDS = {
	"id",
	"name",
	"category",
	"description",
	"timeout",
	"run",
}

local function isNonEmptyString(value)
	return type(value) == "string" and value:match("%S") ~= nil
end

local function validationError(definition)
	if type(definition) ~= "table" then
		return "module must return a test definition table"
	end

	for _, field in ipairs(REQUIRED_FIELDS) do
		if definition[field] == nil then
			return "missing required field '" .. field .. "'"
		end
	end

	for _, field in ipairs({ "id", "name", "category", "description" }) do
		if not isNonEmptyString(definition[field]) then
			return "field '" .. field .. "' must be a non-empty string"
		end
	end

	if type(definition.timeout) ~= "number"
		or definition.timeout <= 0
		or definition.timeout ~= definition.timeout
	then
		return "field 'timeout' must be a positive number"
	end

	if type(definition.run) ~= "function" then
		return "field 'run' must be a function"
	end

	return nil
end

local function defaultContainer()
	return script.Parent:WaitForChild("GameplayTests")
end

function TestRegistry.discover(container)
	container = container or defaultContainer()

	local candidates = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("Test$") then
			table.insert(candidates, child)
		end
	end
	table.sort(candidates, function(left, right)
		return left.Name < right.Name
	end)

	local tests = {}
	local errors = {}
	local seenIds = {}

	for _, moduleScript in ipairs(candidates) do
		local loaded, definition = pcall(require, moduleScript)
		local message
		if not loaded then
			message = "module failed to load: " .. tostring(definition)
		else
			message = validationError(definition)
		end

		if not message and seenIds[definition.id] then
			message = string.format(
				"duplicate test id '%s' (already used by %s)",
				definition.id,
				seenIds[definition.id]
			)
		end

		if message then
			table.insert(errors, {
				moduleName = moduleScript.Name,
				path = moduleScript:GetFullName(),
				message = message,
			})
		else
			seenIds[definition.id] = moduleScript.Name
			table.insert(tests, {
				id = definition.id,
				name = definition.name,
				category = definition.category,
				description = definition.description,
				timeout = definition.timeout,
				run = definition.run,
				module = moduleScript,
			})
		end
	end

	table.sort(tests, function(left, right)
		if left.category ~= right.category then
			return left.category < right.category
		end
		if left.name ~= right.name then
			return left.name < right.name
		end
		return left.id < right.id
	end)

	return tests, errors
end

function TestRegistry.findById(testId, container)
	local tests, errors = TestRegistry.discover(container)
	for _, test in ipairs(tests) do
		if test.id == testId then
			return test, nil, errors
		end
	end
	return nil, "Unknown or invalid BloxQA test: " .. tostring(testId), errors
end

return TestRegistry

]====],
		},
		{
			name = "TestContext",
			className = "ModuleScript",
			source = [====[local Players = game:GetService("Players")

local TestContext = {}
TestContext.__index = TestContext

function TestContext.new(args, testDefinition)
	local self = setmetatable({}, TestContext)
	for key, value in pairs(args or {}) do
		self[key] = value
	end
	self.testId = testDefinition.id
	self.testName = testDefinition.name
	self.timeout = testDefinition.timeout
	self.timeoutSeconds = tonumber(self.timeoutSeconds) or testDefinition.timeout
	return self
end

function TestContext:waitFor(predicate, timeoutSeconds, intervalSeconds)
	local timeout = timeoutSeconds or self.timeout
	local interval = intervalSeconds or 0.05
	local deadline = os.clock() + timeout

	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(interval)
	until os.clock() >= deadline

	return nil
end

function TestContext:getPlayer(timeoutSeconds)
	return self:waitFor(function()
		return Players:GetPlayers()[1]
	end, timeoutSeconds)
end

function TestContext:expect(condition, message)
	if not condition then
		error(message or "Expectation failed", 2)
	end
	return condition
end

function TestContext:fail(message)
	error(message or "Test failed", 2)
end

function TestContext:log(message)
	print(string.format("[BloxQA][%s] %s", self.testId, tostring(message)))
end

return TestContext

]====],
		},
		{
			name = "StudioTestController",
			className = "ModuleScript",
			source = [====[local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local root = ReplicatedStorage:WaitForChild("BloxQA")
local TestRegistry = require(root:WaitForChild("TestRegistry"))
local gameplayTests = root:WaitForChild("GameplayTests")

local StudioTestController = {}

local function failedReport(testName, message, durationMs)
	return {
		total = 1,
		passed = 0,
		failed = 1,
		results = {
			{
				name = testName,
				status = "FAIL",
				passed = false,
				errorMessage = message,
				durationMs = durationMs,
			},
		},
	}
end

function StudioTestController.run(testId, options)
	options = options or {}

	local testDefinition, lookupError = TestRegistry.findById(testId, gameplayTests)
	if not testDefinition then
		return failedReport(tostring(testId), lookupError, 0)
	end

	local startedAt = os.clock()
	local ok, result = pcall(function()
		return StudioTestService:ExecutePlayModeAsync({
			protocol = "BloxQA",
			protocolVersion = 1,
			testId = testDefinition.id,
			timeoutSeconds = options.timeoutSeconds or testDefinition.timeout,
		})
	end)
	local durationMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))

	if not ok then
		return failedReport(
			testDefinition.name,
			"Could not run Studio playtest: " .. tostring(result),
			durationMs
		)
	end

	if type(result) ~= "table" or type(result.results) ~= "table" then
		return failedReport(
			testDefinition.name,
			"StudioTestService returned an invalid result",
			durationMs
		)
	end

	return result
end

return StudioTestController

]====],
		},
		{
			name = "Version",
			className = "ModuleScript",
			source = [====[return {
	major = 0,
	minor = 2,
	patch = 0,
	prerelease = "dev",
	string = "0.2.0-dev",
}
]====],
		},
		{
			name = "GameplayTests",
			className = "Folder",
			children = {
				{
					name = "CharacterTestUtils",
					className = "ModuleScript",
					source = [====[local Players = game:GetService("Players")

local CharacterTestUtils = {}

function CharacterTestUtils.waitUntil(predicate, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds

	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return nil
end

function CharacterTestUtils.waitForPlayer(timeoutSeconds)
	return CharacterTestUtils.waitUntil(function()
		return Players:GetPlayers()[1]
	end, timeoutSeconds)
end

function CharacterTestUtils.waitForCharacter(player, previousCharacter, timeoutSeconds)
	return CharacterTestUtils.waitUntil(function()
		local character = player.Character
		if character and character ~= previousCharacter and character.Parent then
			return character
		end
		return nil
	end, timeoutSeconds)
end

function CharacterTestUtils.waitForChild(parent, childName, timeoutSeconds)
	return CharacterTestUtils.waitUntil(function()
		if not parent.Parent then
			return nil
		end
		return parent:FindFirstChild(childName)
	end, timeoutSeconds)
end

function CharacterTestUtils.validateLiveCharacter(player, previousCharacter, timeoutSeconds)
	local character = CharacterTestUtils.waitForCharacter(player, previousCharacter, timeoutSeconds)
	if not character then
		if previousCharacter then
			return false, nil, nil, string.format(
				"Player did not receive a new Character after %d seconds",
				timeoutSeconds
			)
		end
		return false, nil, nil, string.format(
			"Player.Character was not available after %d seconds",
			timeoutSeconds
		)
	end

	local humanoid = CharacterTestUtils.waitForChild(character, "Humanoid", timeoutSeconds)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return false, character, nil, string.format(
			"Character did not contain a Humanoid after %d seconds",
			timeoutSeconds
		)
	end

	local rootPart = CharacterTestUtils.waitForChild(character, "HumanoidRootPart", timeoutSeconds)
	if not rootPart or not rootPart:IsA("BasePart") then
		return false, character, humanoid, string.format(
			"Character did not contain HumanoidRootPart after %d seconds",
			timeoutSeconds
		)
	end

	if humanoid.Health <= 0 then
		return false, character, humanoid, "Character Humanoid was not alive"
	end

	return true, character, humanoid, nil
end

return CharacterTestUtils

]====],
				},
				{
					name = "PlayerSpawnTest",
					className = "ModuleScript",
					source = [====[local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

return {
	id = "PlayerSpawn",
	name = "Player Spawn Test",
	category = "Gameplay",
	description = "Verifies that the player spawns with a valid character.",
	timeout = 10,
	run = function(ctx)
		local timeoutSeconds = ctx.timeoutSeconds or ctx.timeout or 10
		local player = CharacterTestUtils.waitForPlayer(timeoutSeconds)
		if not player then
			return false, string.format(
				"No Player joined after %d seconds",
				timeoutSeconds
			)
		end

		local valid, _, _, message = CharacterTestUtils.validateLiveCharacter(
			player,
			nil,
			timeoutSeconds
		)
		if not valid then
			return false, message
		end

		return true
	end,
}

]====],
				},
				{
					name = "PlayerRespawnTest",
					className = "ModuleScript",
					source = [====[local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

return {
	id = "PlayerRespawn",
	name = "Player Respawn Test",
	category = "Gameplay",
	description = "Verifies that the player receives a distinct valid character after death.",
	timeout = 10,
	run = function(ctx)
		local timeoutSeconds = ctx.timeoutSeconds or ctx.timeout or 10
		local player = CharacterTestUtils.waitForPlayer(timeoutSeconds)
		if not player then
			return false, string.format(
				"No Player joined after %d seconds",
				timeoutSeconds
			)
		end

		local initialValid, oldCharacter, oldHumanoid, initialMessage =
			CharacterTestUtils.validateLiveCharacter(player, nil, timeoutSeconds)
		if not initialValid then
			return false, "Initial spawn failed: " .. initialMessage
		end

		oldHumanoid.Health = 0
		print(string.format(
			"[BloxQA] Respawn: set %s Humanoid.Health to 0",
			player.Name
		))

		local diedOrRemoved = CharacterTestUtils.waitUntil(function()
			return oldHumanoid.Health <= 0 or oldCharacter.Parent == nil
		end, 5)
		if not diedOrRemoved then
			return false, "Old Character did not die or get removed after 5 seconds"
		end

		local respawnValid, newCharacter, _, respawnMessage =
			CharacterTestUtils.validateLiveCharacter(
				player,
				oldCharacter,
				timeoutSeconds
			)
		if not respawnValid then
			return false, respawnMessage
		end

		if newCharacter == oldCharacter then
			return false, "Respawn reused the old Character"
		end

		print("[BloxQA] Respawn: detected a distinct new Character")
		return true
	end,
}

]====],
				},
				{
					name = "ExampleTestTemplate",
					className = "ModuleScript",
					source = [====[-- BloxQA test authoring template.
-- Duplicate this module, rename the copy so its name ends in "Test",
-- then replace the sample metadata and assertions below.
-- This template is ignored by automatic discovery because its name does not end in "Test".

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

]====],
				},
			},
		},
	},
}

RuntimeTemplate.serverHarness = {
	name = "BloxQAGameplayTestServer",
	className = "Script",
	disabled = true,
	source = [====[local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

if not RunService:IsStudio() then
	return
end

local gotArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)

if not gotArgs
	or type(args) ~= "table"
	or args.protocol ~= "BloxQA"
	or args.protocolVersion ~= 1
then
	return
end

local root = ReplicatedStorage:WaitForChild("BloxQA")
local TestRunner = require(root:WaitForChild("TestRunner"))
local TestRegistry = require(root:WaitForChild("TestRegistry"))
local TestContext = require(root:WaitForChild("TestContext"))
local gameplayTests = root:WaitForChild("GameplayTests")

local testDefinition, lookupError, discoveryErrors = TestRegistry.findById(args.testId, gameplayTests)
for _, discoveryError in ipairs(discoveryErrors) do
	warn(string.format(
		"[BloxQA] Ignoring invalid test module %s: %s",
		discoveryError.path,
		discoveryError.message
	))
end

if not testDefinition then
	local name = tostring(args.testId)
	StudioTestService:EndTest({
		total = 1,
		passed = 0,
		failed = 1,
		results = {
			{
				name = name,
				status = "FAIL",
				passed = false,
				errorMessage = lookupError,
				durationMs = 0,
			},
		},
	})
	return
end

print(string.format("[BloxQA] Starting StudioTestService test: %s", args.testId))

local context = TestContext.new(args, testDefinition)

local originalRun = testDefinition.run
local runnableTest = {
	name = testDefinition.name,
	run = function()
		return originalRun(context)
	end,
}

local report = TestRunner.run({ runnableTest })
local result = report.results[1]

print(string.format(
	"[BloxQA] %s — %s — %dms%s",
	result.status,
	result.name,
	result.durationMs,
	result.errorMessage and (" — " .. result.errorMessage) or ""
))

StudioTestService:EndTest(report)

]====],
}

return RuntimeTemplate


