local StudioTestService = game:GetService("StudioTestService")

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
	local testName = options.testName or tostring(testId)
	local timeoutSeconds = options.timeoutSeconds or 10

	if type(testId) ~= "string" or testId == "" then
		return failedReport(testName, "A valid discovered test ID is required", 0)
	end

	local startedAt = os.clock()
	local ok, result = pcall(function()
		return StudioTestService:ExecutePlayModeAsync({
			protocol = "BloxQA",
			protocolVersion = 1,
			testId = testId,
			timeoutSeconds = timeoutSeconds,
		})
	end)
	local durationMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))

	if not ok then
		return failedReport(
			testName,
			"Could not run Studio playtest: " .. tostring(result),
			durationMs
		)
	end

	if type(result) ~= "table" or type(result.results) ~= "table" then
		return failedReport(
			testName,
			"StudioTestService returned an invalid result. Is the BloxQA per-place runtime installed?",
			durationMs
		)
	end

	return result
end

return StudioTestController

