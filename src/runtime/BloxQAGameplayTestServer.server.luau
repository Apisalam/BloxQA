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

