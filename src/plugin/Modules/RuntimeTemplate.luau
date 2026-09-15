local RuntimeTemplate = {
	runtimeVersion = "0.3.0-dev",
	schemaVersion = 2,
}

RuntimeTemplate.runtimeRoot = {
	name = "BloxQA",
	className = "Folder",
	children = {
		{
			name = "TestRunner",
			className = "ModuleScript",
			source = [========[local TestRunner = {}

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
]========],
		},
		{
			name = "TestRegistry",
			className = "ModuleScript",
			source = [========[local TestRegistry = {}

local REQUIRED_FIELDS = {
	"id",
	"name",
	"category",
	"description",
	"timeout",
	"run",
}

local VALID_MODES = {
	singleplayer = true,
	multiplayer = true,
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

	local mode = definition.mode or "singleplayer"
	if not VALID_MODES[mode] then
		return "field 'mode' must be 'singleplayer' or 'multiplayer'"
	end

	if mode == "multiplayer" then
		if type(definition.players) ~= "number"
			or definition.players % 1 ~= 0
			or definition.players < 2
			or definition.players > 8
		then
			return "multiplayer field 'players' must be an integer from 2 to 8"
		end
	elseif definition.players ~= nil and definition.players ~= 1 then
		return "singleplayer field 'players' must be 1 when provided"
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
				mode = definition.mode or "singleplayer",
				players = definition.mode == "multiplayer" and definition.players or 1,
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
]========],
		},
		{
			name = "TestContext",
			className = "ModuleScript",
			source = [========[local MultiplayerCoordinator = require(script.Parent:WaitForChild("MultiplayerCoordinator"))

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
	self.mode = testDefinition.mode or "singleplayer"
	self.expectedPlayers = self.mode == "multiplayer" and testDefinition.players or 1
	self.multiplayer = MultiplayerCoordinator.new(self.mode, self.expectedPlayers)
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
	local participants = self.multiplayer:waitForPlayerCount(
		self.expectedPlayers,
		timeoutSeconds or self.timeout
	)
	return participants and participants[1] or nil
end

function TestContext:getParticipants(timeoutSeconds)
	return self.multiplayer:waitForPlayerCount(
		self.expectedPlayers,
		timeoutSeconds or self.timeout
	)
end

function TestContext:waitForParticipantCount(count, timeoutSeconds)
	return self.multiplayer:waitForPlayerCount(count, timeoutSeconds or self.timeout)
end

function TestContext:waitForCharacter(player, timeoutSeconds)
	return self.multiplayer:waitForCharacter(player, timeoutSeconds or self.timeout)
end

function TestContext:requestPlayerLeave(player, timeoutSeconds)
	return self.multiplayer:requestPlayerLeave(player, timeoutSeconds or self.timeout)
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

function TestContext:cleanup()
	if self.multiplayer then
		self.multiplayer:destroy()
		self.multiplayer = nil
	end
end

return TestContext
]========],
		},
		{
			name = "MultiplayerCoordinator",
			className = "ModuleScript",
			source = [========[local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MultiplayerCoordinator = {}
MultiplayerCoordinator.__index = MultiplayerCoordinator

local function sortedPlayers()
	local participants = Players:GetPlayers()
	table.sort(participants, function(left, right)
		if left.UserId ~= right.UserId then
			return left.UserId < right.UserId
		end
		return left.Name < right.Name
	end)
	return participants
end

function MultiplayerCoordinator.new(mode, expectedPlayers)
	local self = setmetatable({}, MultiplayerCoordinator)
	self.mode = mode
	self.expectedPlayers = expectedPlayers
	self.responses = {}

	if mode == "multiplayer" then
		local root = ReplicatedStorage:WaitForChild("BloxQA")
		local existing = root:FindFirstChild("MultiplayerBridge")
		if existing then
			existing:Destroy()
		end

		local bridge = Instance.new("RemoteEvent")
		bridge.Name = "MultiplayerBridge"
		bridge.Parent = root
		self.bridge = bridge
		self.bridgeConnection = bridge.OnServerEvent:Connect(function(player, responseType, requestId, detail)
			if responseType == "LeaveReady" or responseType == "LeaveUnavailable" then
				self.responses[requestId] = {
					player = player,
					ready = responseType == "LeaveReady",
					detail = tostring(detail or ""),
				}
			end
		end)
	end

	return self
end

function MultiplayerCoordinator:getPlayers()
	return sortedPlayers()
end

function MultiplayerCoordinator:waitForPlayerCount(count, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		local participants = sortedPlayers()
		if #participants == count then
			return participants
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return nil, string.format(
		"Timed out waiting for %d participant%s; observed %d",
		count,
		count == 1 and "" or "s",
		#Players:GetPlayers()
	)
end

function MultiplayerCoordinator:waitForCharacter(player, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		if player.Parent ~= Players then
			return nil, "Participant left before the character became ready"
		end

		local character = player.Character
		if character
			and character:FindFirstChildOfClass("Humanoid")
			and character:FindFirstChild("HumanoidRootPart")
		then
			return character
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return nil, "Participant character did not become ready before timeout"
end

function MultiplayerCoordinator:requestPlayerLeave(player, timeoutSeconds)
	if self.mode ~= "multiplayer" or not self.bridge then
		return false, "Player leave requires an active BloxQA multiplayer session"
	end
	if player.Parent ~= Players then
		return false, "Selected participant is no longer connected"
	end

	local requestId = HttpService:GenerateGUID(false)
	local removed = false
	local removingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			removed = true
		end
	end)

	self.bridge:FireClient(player, "LeaveTest", requestId)
	local deadline = os.clock() + timeoutSeconds
	repeat
		if removed or player.Parent ~= Players then
			removingConnection:Disconnect()
			return true
		end

		local response = self.responses[requestId]
		if response and not response.ready then
			removingConnection:Disconnect()
			return false, response.detail ~= "" and response.detail
				or "Studio reported that this client cannot leave the test"
		end
		task.wait(0.05)
	until os.clock() >= deadline

	removingConnection:Disconnect()
	return false, "Timed out waiting for the selected participant to leave"
end

function MultiplayerCoordinator:destroy()
	if self.bridgeConnection then
		self.bridgeConnection:Disconnect()
		self.bridgeConnection = nil
	end
	if self.bridge then
		self.bridge:Destroy()
		self.bridge = nil
	end
end

return MultiplayerCoordinator
]========],
		},
		{
			name = "StudioTestController",
			className = "ModuleScript",
			source = [========[local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local root = ReplicatedStorage:WaitForChild("BloxQA")
local TestRegistry = require(root:WaitForChild("TestRegistry"))
local gameplayTests = root:WaitForChild("GameplayTests")

local StudioTestController = {}

local function failedReport(testName, message, durationMs, mode, expectedPlayers)
	return {
		total = 1,
		passed = 0,
		failed = 1,
		results = {
			{
				name = testName,
				mode = mode or "singleplayer",
				expectedPlayers = expectedPlayers or 1,
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
	local mode = testDefinition.mode
	local expectedPlayers = testDefinition.players

	local startedAt = os.clock()
	local ok, result = pcall(function()
		local args = {
			protocol = "BloxQA",
			protocolVersion = 2,
			testId = testDefinition.id,
			timeoutSeconds = options.timeoutSeconds or testDefinition.timeout,
			mode = mode,
			expectedPlayers = expectedPlayers,
		}
		if mode == "multiplayer" then
			return StudioTestService:ExecuteMultiplayerTestAsync(expectedPlayers, args)
		end
		return StudioTestService:ExecutePlayModeAsync(args)
	end)
	local durationMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))

	if not ok then
		return failedReport(
			testDefinition.name,
			"Could not run Studio playtest: " .. tostring(result),
			durationMs,
			mode,
			expectedPlayers
		)
	end

	if type(result) ~= "table" or type(result.results) ~= "table" then
		return failedReport(
			testDefinition.name,
			"StudioTestService returned an invalid result",
			durationMs,
			mode,
			expectedPlayers
		)
	end

	return result
end

return StudioTestController
]========],
		},
		{
			name = "Version",
			className = "ModuleScript",
			source = [========[return {
	major = 0,
	minor = 3,
	patch = 0,
	prerelease = "dev",
	string = "0.3.0-dev",
}
]========],
		},
		{
			name = "GameplayTests",
			className = "Folder",
			children = {
				{
					name = "CharacterTestUtils",
					className = "ModuleScript",
					source = [========[local Players = game:GetService("Players")

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
]========],
				},
				{
					name = "PlayerSpawnTest",
					className = "ModuleScript",
					source = [========[local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

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
]========],
				},
				{
					name = "PlayerRespawnTest",
					className = "ModuleScript",
					source = [========[local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

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
]========],
				},
				{
					name = "TwoPlayerPresenceTest",
					className = "ModuleScript",
					source = [========[return {
	id = "TwoPlayerPresence",
	name = "Two Player Presence Test",
	category = "Multiplayer",
	description = "Verifies that two simulated players join with ready characters.",
	timeout = 20,
	mode = "multiplayer",
	players = 2,

	run = function(ctx)
		local participants, participantError = ctx:getParticipants()
		ctx:expect(participants ~= nil, participantError)
		ctx:expect(#participants == 2, "Expected exactly two simulated participants")
		ctx:expect(participants[1] ~= participants[2], "Expected two distinct Player instances")

		local characters = {}
		for index, participant in ipairs(participants) do
			ctx:expect(participant.Parent ~= nil, "Participant " .. index .. " is not connected")
			local character, characterError = ctx:waitForCharacter(participant)
			ctx:expect(character ~= nil, characterError)
			characters[index] = character

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			ctx:expect(humanoid ~= nil, "Participant " .. index .. " character is missing a Humanoid")
			ctx:expect(humanoid.Health > 0, "Participant " .. index .. " Humanoid is not alive")
			ctx:expect(
				character:FindFirstChild("HumanoidRootPart") ~= nil,
				"Participant " .. index .. " character is missing HumanoidRootPart"
			)
		end
		ctx:expect(characters[1] ~= characters[2], "Expected two distinct Character instances")

		task.wait(1)
		for index, participant in ipairs(participants) do
			ctx:expect(participant.Parent ~= nil, "Participant " .. index .. " left during the assertion window")
			ctx:expect(participant.Character == characters[index], "Participant " .. index .. " character changed during the assertion window")
			local humanoid = characters[index]:FindFirstChildOfClass("Humanoid")
			ctx:expect(humanoid and humanoid.Health > 0, "Participant " .. index .. " did not remain alive")
			ctx:expect(
				characters[index]:FindFirstChild("HumanoidRootPart") ~= nil,
				"Participant " .. index .. " lost HumanoidRootPart during the assertion window"
			)
		end

		ctx:log("Two simulated participants joined with ready characters")
		return true
	end,
}
]========],
				},
				{
					name = "PlayerLeaveTest",
					className = "ModuleScript",
					source = [========[return {
	id = "PlayerLeave",
	name = "Player Leave Test",
	category = "Multiplayer",
	description = "Verifies that one simulated client can leave while the other remains active.",
	timeout = 25,
	mode = "multiplayer",
	players = 2,

	run = function(ctx)
		local participants, participantError = ctx:getParticipants()
		ctx:expect(participants ~= nil, participantError)

		for _, participant in ipairs(participants) do
			local character, characterError = ctx:waitForCharacter(participant)
			ctx:expect(character ~= nil, characterError)
		end

		local departed, leaveError = ctx:requestPlayerLeave(participants[2], 10)
		ctx:expect(departed, leaveError)

		local remaining, remainingError = ctx:waitForParticipantCount(1, 5)
		ctx:expect(remaining ~= nil, remainingError)
		local character, characterError = ctx:waitForCharacter(remaining[1], 5)
		ctx:expect(character ~= nil, characterError)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		ctx:expect(humanoid and humanoid.Health > 0, "Remaining participant was not alive after the leave")

		ctx:log("One simulated participant left and one remained active")
		return true
	end,
}
]========],
				},
				{
					name = "ExampleTestTemplate",
					className = "ModuleScript",
					source = [========[-- BloxQA test authoring template.
-- Duplicate this module, rename the copy so its name ends in "Test",
-- then replace the sample metadata and assertions below.
-- This template is ignored by automatic discovery because its name does not end in "Test".

return {
	id = "MyTest",
	name = "My Test",
	category = "Gameplay",
	description = "Describe what this verifies.",
	timeout = 10,
	-- Single-player is the default. For a multiplayer test, add:
	-- mode = "multiplayer",
	-- players = 2, -- integer from 2 through 8

	run = function(ctx)
		ctx:log("Starting My Test")

		local player = ctx:getPlayer()
		ctx:expect(player ~= nil, "No Player joined before the timeout")

		-- Add assertions here.
		return true
	end,
}
]========],
				},
			},
		},
	},
}

RuntimeTemplate.serverHarness = {
	name = "BloxQAGameplayTestServer",
	className = "Script",
	disabled = false,
	source = [========[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
	or args.protocolVersion ~= 2
then
	return
end

local root = ReplicatedStorage:WaitForChild("BloxQA")
local TestRunner = require(root:WaitForChild("TestRunner"))
local TestRegistry = require(root:WaitForChild("TestRegistry"))
local TestContext = require(root:WaitForChild("TestContext"))
local gameplayTests = root:WaitForChild("GameplayTests")

local function failureReport(name, message, mode, expectedPlayers, durationMs)
	return {
		total = 1,
		passed = 0,
		failed = 1,
		mode = mode,
		expectedPlayers = expectedPlayers,
		playerCount = #Players:GetPlayers(),
		results = {
			{
				testId = tostring(args.testId),
				name = name,
				mode = mode,
				expectedPlayers = expectedPlayers,
				playerCount = #Players:GetPlayers(),
				status = "FAIL",
				passed = false,
				errorMessage = tostring(message),
				durationMs = math.max(0, tonumber(durationMs) or 0),
			},
		},
	}
end

local testDefinition, lookupError, discoveryErrors = TestRegistry.findById(args.testId, gameplayTests)
for _, discoveryError in ipairs(discoveryErrors) do
	warn(string.format(
		"[BloxQA] Ignoring invalid test module %s: %s",
		discoveryError.path,
		discoveryError.message
	))
end

if not testDefinition then
	StudioTestService:EndTest(failureReport(
		tostring(args.testId),
		lookupError,
		tostring(args.mode or "singleplayer"),
		tonumber(args.expectedPlayers) or 1,
		0
	))
	return
end

if args.mode ~= testDefinition.mode or args.expectedPlayers ~= testDefinition.players then
	StudioTestService:EndTest(failureReport(
		testDefinition.name,
		"Controller metadata did not match the discovered test definition",
		testDefinition.mode,
		testDefinition.players,
		0
	))
	return
end

print(string.format(
	"[BloxQA] Starting %s StudioTestService test: %s (%d player%s)",
	testDefinition.mode,
	args.testId,
	testDefinition.players,
	testDefinition.players == 1 and "" or "s"
))

local context = TestContext.new(args, testDefinition)
local originalRun = testDefinition.run
local runnableTest = {
	name = testDefinition.name,
	run = function()
		return originalRun(context)
	end,
}

local startedAt = os.clock()
local completed = false
local report
task.spawn(function()
	report = TestRunner.run({ runnableTest })
	completed = true
end)

local hardDeadline = startedAt + testDefinition.timeout + 3
while not completed and os.clock() < hardDeadline do
	task.wait(0.05)
end

if not completed then
	report = failureReport(
		testDefinition.name,
		string.format("Test exceeded its %g second timeout", testDefinition.timeout),
		testDefinition.mode,
		testDefinition.players,
		math.floor((os.clock() - startedAt) * 1000 + 0.5)
	)
end

local result = report.results[1]
result.testId = testDefinition.id
result.mode = testDefinition.mode
result.expectedPlayers = testDefinition.players
result.playerCount = #Players:GetPlayers()
report.mode = testDefinition.mode
report.expectedPlayers = testDefinition.players
report.playerCount = result.playerCount

print(string.format(
	"[BloxQA] %s — %s — %dms — players %d/%d%s",
	result.status,
	result.name,
	result.durationMs,
	result.playerCount,
	result.expectedPlayers,
	result.errorMessage and (" — " .. result.errorMessage) or ""
))

context:cleanup()
StudioTestService:EndTest(report)
]========],
}

RuntimeTemplate.clientHarness = {
	name = "BloxQAMultiplayerTestClient",
	className = "LocalScript",
	disabled = false,
	source = [========[local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

if not RunService:IsStudio() then
	return
end

local root = ReplicatedStorage:WaitForChild("BloxQA", 30)
if not root then
	return
end

local bridge = root:WaitForChild("MultiplayerBridge", 30)
if not bridge or not bridge:IsA("RemoteEvent") then
	return
end

bridge.OnClientEvent:Connect(function(command, requestId)
	if command ~= "LeaveTest" then
		return
	end

	local canCheck, canLeave = pcall(function()
		return StudioTestService:CanLeaveTest()
	end)
	if not canCheck or not canLeave then
		bridge:FireServer(
			"LeaveUnavailable",
			requestId,
			canCheck and "Studio reported that this client cannot leave the test"
				or "Could not check whether this client can leave the test"
		)
		return
	end

	bridge:FireServer("LeaveReady", requestId)
	task.defer(function()
		local ok, message = pcall(function()
			StudioTestService:LeaveTest()
		end)
		if not ok then
			warn("[BloxQA] Client failed to leave multiplayer test: " .. tostring(message))
		end
	end)
end)
]========],
}

return RuntimeTemplate

