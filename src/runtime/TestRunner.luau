local TestRunner = {}

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

