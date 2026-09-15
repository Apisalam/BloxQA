local Players = game:GetService("Players")
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
