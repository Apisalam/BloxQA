local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Version = require(script.Parent:WaitForChild("Version"))
local TestRegistry = require(script.Parent:WaitForChild("TestRegistry"))
local HistoryStore = require(script.Parent:WaitForChild("HistoryStore"))
local StudioTestController = require(script.Parent:WaitForChild("StudioTestController"))
local ProjectInitializer = require(script.Parent:WaitForChild("ProjectInitializer"))

local PluginMain = {}

local COLORS = {
	panel = Color3.fromRGB(37, 37, 38),
	surface = Color3.fromRGB(45, 45, 48),
	surfaceAlt = Color3.fromRGB(51, 51, 54),
	text = Color3.fromRGB(240, 240, 240),
	muted = Color3.fromRGB(180, 180, 180),
	button = Color3.fromRGB(0, 122, 204),
	buttonDisabled = Color3.fromRGB(74, 74, 77),
	pass = Color3.fromRGB(78, 201, 176),
	fail = Color3.fromRGB(244, 135, 113),
	warning = Color3.fromRGB(220, 190, 105),
}

local function create(className, properties)
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
	return instance
end

local function rounded(parent, radius)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius or 4),
		Parent = parent,
	})
end

local function clearGenerated(parent, attributeName)
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute(attributeName) then
			child:Destroy()
		end
	end
end

local function failedResult(test, message, durationMs)
	return {
		testId = test.id,
		name = test.name,
		mode = test.mode or "singleplayer",
		expectedPlayers = test.players or 1,
		playerCount = nil,
		status = "FAIL",
		passed = false,
		errorMessage = tostring(message),
		durationMs = math.max(0, tonumber(durationMs) or 0),
	}
end

local function normalizeResult(test, report, fallbackDurationMs)
	if type(report) ~= "table" or type(report.results) ~= "table" then
		return failedResult(test, "StudioTestService returned a malformed result", fallbackDurationMs)
	end

	local result = report.results[1]
	if type(result) ~= "table" then
		return failedResult(test, "StudioTestService returned a malformed test result", fallbackDurationMs)
	end
	if type(result.passed) ~= "boolean" then
		return failedResult(test, "Test result did not include a valid passed value", fallbackDurationMs)
	end

	local durationMs = tonumber(result.durationMs)
	if not durationMs or durationMs < 0 then
		return failedResult(test, "Test result did not include a valid duration", fallbackDurationMs)
	end

	return {
		testId = test.id,
		name = type(result.name) == "string" and result.name or test.name,
		mode = result.mode or test.mode or "singleplayer",
		expectedPlayers = tonumber(result.expectedPlayers) or test.players or 1,
		playerCount = tonumber(result.playerCount),
		status = result.passed and "PASS" or "FAIL",
		passed = result.passed,
		errorMessage = result.errorMessage and tostring(result.errorMessage) or nil,
		durationMs = math.floor(durationMs + 0.5),
	}
end

function PluginMain.start(pluginInstance)
	assert(pluginInstance, "BloxQA requires a Roblox Studio plugin context")

	local toolbar = pluginInstance:CreateToolbar("BloxQA")
	local toolbarButton = toolbar:CreateButton("BloxQA", "Open BloxQA automated gameplay testing", "")
	toolbarButton.ClickableWhenViewportHidden = true

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		400,
		620,
		340,
		420
	)
	local widget = pluginInstance:CreateDockWidgetPluginGuiAsync("BloxQA_Milestone3", widgetInfo)
	widget.Name = "BloxQA"
	widget.Title = "BloxQA"

	local root = create("ScrollingFrame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = widget,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = root,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = root,
	})

	create("TextLabel", {
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		Text = "BloxQA",
		TextColor3 = COLORS.text,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	create("TextLabel", {
		Name = "Subtitle",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		Text = "Automated gameplay testing · v" .. Version.string,
		TextColor3 = COLORS.muted,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	local status = create("TextLabel", {
		Name = "Status",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "Ready",
		TextColor3 = COLORS.text,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	rounded(status)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = status,
	})

	local diagnostics = create("TextLabel", {
		Name = "RegistryDiagnostics",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = COLORS.surfaceAlt,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "Registry diagnostics loading...",
		TextColor3 = COLORS.muted,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = root,
	})
	rounded(diagnostics)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = diagnostics,
	})

	local onboarding = create("Frame", {
		Name = "ProjectOnboarding",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 154),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	})
	rounded(onboarding)
	local onboardingTitle = create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		Text = "No BloxQA project detected",
		TextColor3 = COLORS.text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = onboarding,
	})
	local onboardingDescription = create("TextLabel", {
		Name = "Description",
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.fromOffset(10, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		Text = "Set up BloxQA in this experience to begin automated testing.",
		TextColor3 = COLORS.muted,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = onboarding,
	})
	local initializeButton = create("TextButton", {
		Name = "InitializeBloxQA",
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 1, -46),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansSemibold,
		Text = "Initialize BloxQA",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Parent = onboarding,
	})
	rounded(initializeButton)
	local repairButton = create("TextButton", {
		Name = "RepairBloxQA",
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 1, -46),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansSemibold,
		Text = "Repair BloxQA",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Visible = false,
		Parent = onboarding,
	})
	rounded(repairButton)

	local filterBar = create("Frame", {
		Name = "CategoryFilters",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = root,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = filterBar,
	})

	local testList = create("Frame", {
		Name = "TestList",
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local testListLayout = create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = testList,
	})

	local runAllButton = create("TextButton", {
		Name = "RunAllGameplayTests",
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansSemibold,
		Text = "Run All Visible Tests",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Parent = root,
	})
	rounded(runAllButton)

	local summary = create("TextLabel", {
		Name = "Summary",
		LayoutOrder = 8,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "Total: 0   Passed: 0   Failed: 0\nDuration: 0ms",
		TextColor3 = COLORS.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = root,
	})
	rounded(summary)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = summary,
	})

	local results = create("Frame", {
		Name = "Results",
		LayoutOrder = 9,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		Parent = root,
	})
	rounded(results)
	local resultsLayout = create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = results,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		Parent = results,
	})

	local historyToggle = create("TextButton", {
		Name = "HistoryToggle",
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansSemibold,
		Text = "Recent Runs ▸",
		TextColor3 = COLORS.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	rounded(historyToggle)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		Parent = historyToggle,
	})

	local historyFrame = create("Frame", {
		Name = "History",
		LayoutOrder = 11,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = COLORS.surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Parent = root,
	})
	rounded(historyFrame)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = historyFrame,
	})
	local historyLayout = create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = historyFrame,
	})

	local controller = StudioTestController
	local controllerError = nil
	local gameplayTests = nil
	local placeRuntimeError = nil
	local projectInspection = nil

	local function resolvePlaceRuntime()
		local inspection = ProjectInitializer.inspect()
		if not inspection.healthy then
			local detail = #inspection.issues > 0 and (" " .. table.concat(inspection.issues, " ")) or ""
			return nil, inspection.message .. detail, inspection
		end
		return inspection.root:FindFirstChild("GameplayTests"), nil, inspection
	end

	local history = HistoryStore.new(pluginInstance)
	local tests = {}
	local discoveryErrors = {}
	local runButtons = {}
	local renderedResults = {}
	local busy = false
	local historyExpanded = false
	local selectedCategory = nil
	local refreshTests
	local runOne

	local function setBusy(value)
		busy = value
		for _, button in pairs(runButtons) do
			button.Active = not value
			button.AutoButtonColor = not value
			button.BackgroundColor3 = value and COLORS.buttonDisabled or COLORS.button
		end
		runAllButton.Active = not value
		runAllButton.AutoButtonColor = not value
		runAllButton.BackgroundColor3 = value and COLORS.buttonDisabled or COLORS.button
		for _, button in ipairs({ initializeButton, repairButton }) do
			button.Active = not value
			button.AutoButtonColor = not value
			button.BackgroundColor3 = value and COLORS.buttonDisabled or COLORS.button
		end
	end

	local function renderProjectState()
		local healthy = projectInspection and projectInspection.healthy
		onboarding.Visible = not healthy
		for _, control in ipairs({ filterBar, testList, runAllButton, summary, results, historyToggle }) do
			control.Visible = healthy
		end
		historyFrame.Visible = healthy and historyExpanded
		if healthy then
			return
		end

		local missing = projectInspection and projectInspection.state == "missing"
		onboardingTitle.Text = missing and "No BloxQA project detected" or "BloxQA project needs attention"
		onboardingDescription.Text = missing
			and "Set up BloxQA in this experience to begin automated testing."
			or (projectInspection and table.concat(projectInspection.issues, "\n") or "Unable to inspect this place.")
		initializeButton.Visible = missing
		repairButton.Visible = not missing and projectInspection and projectInspection.repairable or false
		onboarding.Size = UDim2.new(1, 0, 0, missing and 154 or math.max(154, 98 + 28 * #(projectInspection and projectInspection.issues or {})))
	end

	local function getCategories()
		local seen = {}
		local categories = {}
		for _, test in ipairs(tests) do
			if not seen[test.category] then
				seen[test.category] = true
				table.insert(categories, test.category)
			end
		end
		table.sort(categories)
		return categories
	end

	local function getVisibleTests()
		if not selectedCategory then
			return tests
		end
		local visible = {}
		for _, test in ipairs(tests) do
			if test.category == selectedCategory then
				table.insert(visible, test)
			end
		end
		return visible
	end

	local function updateSummary(items)
		local passed = 0
		local durationMs = 0
		for _, result in ipairs(items) do
			if result.passed then
				passed += 1
			end
			durationMs += result.durationMs
		end
		summary.Text = string.format(
			"Total: %d   Passed: %d   Failed: %d\nDuration: %dms",
			#items,
			passed,
			#items - passed,
			durationMs
		)
		widget:SetAttribute("LastTotal", #items)
		widget:SetAttribute("LastPassed", passed)
		widget:SetAttribute("LastFailed", #items - passed)
		widget:SetAttribute("LastDurationMs", durationMs)
	end

	local function renderResults()
		clearGenerated(results, "BloxQAResult")
		for index, result in ipairs(renderedResults) do
			local hasError = result.errorMessage ~= nil and result.errorMessage ~= ""
			local playerLine = result.mode == "multiplayer" and string.format(
				"\nPlayers: %s/%d",
				result.playerCount and tostring(result.playerCount) or "?",
				result.expectedPlayers
			) or ""
			local label = create("TextLabel", {
				Name = result.passed and "PassResult" or "FailResult",
				LayoutOrder = index,
				Size = UDim2.new(1, -14, 0, (hasError and 60 or 34) + (playerLine ~= "" and 20 or 0)),
				BackgroundColor3 = result.passed
					and Color3.fromRGB(31, 61, 53)
					or Color3.fromRGB(73, 42, 39),
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				Text = string.format(
					"%s %s — %s — %dms%s%s",
					result.passed and "✓" or "✕",
					result.status,
					result.name,
					result.durationMs,
					playerLine,
					hasError and ("\n" .. result.errorMessage) or ""
				),
				TextColor3 = result.passed and COLORS.pass or COLORS.fail,
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Parent = results,
			})
			label:SetAttribute("BloxQAResult", true)
			rounded(label)
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 9),
				PaddingRight = UDim.new(0, 9),
				Parent = label,
			})
		end
		results.Size = UDim2.new(1, 0, 0, math.max(48, resultsLayout.AbsoluteContentSize.Y + 14))
		updateSummary(renderedResults)
	end

	local function renderHistory()
		clearGenerated(historyFrame, "BloxQAHistory")
		local entries = history:getAll()
		local visibleCount = math.min(#entries, 5)
		if visibleCount == 0 then
			local empty = create("TextLabel", {
				Name = "Empty",
				LayoutOrder = 1,
				Size = UDim2.new(1, -16, 0, 24),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Text = "No test runs recorded yet.",
				TextColor3 = COLORS.muted,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = historyFrame,
			})
			empty:SetAttribute("BloxQAHistory", true)
		else
			for index = 1, visibleCount do
				local entry = entries[index]
				local timestamp = os.date("%H:%M", entry.timestamp)
				local line = create("TextLabel", {
					Name = "HistoryEntry",
					LayoutOrder = index,
					Size = UDim2.new(1, -16, 0, 26),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					Text = string.format(
						"%s  %s %s  %.1fs",
						timestamp,
						entry.status == "PASS" and "✓" or "✕",
						entry.testName,
						entry.durationMs / 1000
					),
					TextColor3 = entry.status == "PASS" and COLORS.pass or COLORS.fail,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = historyFrame,
				})
				line:SetAttribute("BloxQAHistory", true)
			end
		end

		historyFrame.Visible = historyExpanded
		historyFrame.Size = historyExpanded
			and UDim2.new(1, 0, 0, historyLayout.AbsoluteContentSize.Y + 14)
			or UDim2.new(1, 0, 0, 0)
		historyToggle.Text = historyExpanded and "Recent Runs ▾" or "Recent Runs ▸"
	end

	local function renderDiagnostics()
		local lines = {
			string.format(
				"BloxQA v%s · %d valid test%s · %d invalid",
				Version.string,
				#tests,
				#tests == 1 and "" or "s",
				#discoveryErrors
			),
		}
		if placeRuntimeError then
			table.insert(lines, "⚠ " .. placeRuntimeError)
		end
		for _, discoveryError in ipairs(discoveryErrors) do
			table.insert(lines, string.format(
				"⚠ %s — %s",
				discoveryError.moduleName,
				discoveryError.message
			))
		end
		local issueCount = #discoveryErrors + (placeRuntimeError and 1 or 0)
		diagnostics.Text = table.concat(lines, "\n")
		diagnostics.TextColor3 = issueCount > 0 and COLORS.warning or COLORS.muted
		diagnostics.Size = UDim2.new(1, 0, 0, 32 + issueCount * 44)
	end

	local function renderFilters()
		clearGenerated(filterBar, "BloxQAFilter")
		local categories = getCategories()
		if selectedCategory then
			local stillAvailable = false
			for _, category in ipairs(categories) do
				if category == selectedCategory then
					stillAvailable = true
					break
				end
			end
			if not stillAvailable then
				selectedCategory = nil
			end
		end

		local function addFilter(label, category, layoutOrder)
			local selected = selectedCategory == category
			local button = create("TextButton", {
				Name = category and (category:gsub("%W", "") .. "Filter") or "AllFilter",
				LayoutOrder = layoutOrder,
				Size = UDim2.fromOffset(math.max(48, 24 + #label * 7), 28),
				BackgroundColor3 = selected and COLORS.button or COLORS.surfaceAlt,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSansSemibold,
				Text = label,
				TextColor3 = COLORS.text,
				TextSize = 13,
				Active = not busy,
				AutoButtonColor = not busy,
				Parent = filterBar,
			})
			button:SetAttribute("BloxQAFilter", true)
			rounded(button)
			button.Activated:Connect(function()
				if busy then
					return
				end
				selectedCategory = category
				refreshTests()
			end)
		end

		addFilter("All", nil, 1)
		for index, category in ipairs(categories) do
			addFilter(category, category, index + 1)
		end

		runAllButton.Text = selectedCategory
			and ("Run All " .. selectedCategory .. " Tests")
			or "Run All Visible Tests"
	end

	local function execute(test)
		local startedAt = os.clock()
		if not controller or type(controller.run) ~= "function" then
			return failedResult(
				test,
				"StudioTestController is unavailable: " .. tostring(controllerError or "invalid module"),
				0
			)
		end

		local completed = false
		local ok
		local report
			task.spawn(function()
				ok, report = pcall(controller.run, test.id, {
					timeoutSeconds = test.timeout,
					testName = test.name,
					mode = test.mode,
					players = test.players,
				})
			completed = true
		end)

		local watchdogSeconds = test.timeout + 10
		while not completed and os.clock() - startedAt < watchdogSeconds do
			task.wait(0.1)
		end

		local elapsedMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))
		if not completed then
			return failedResult(
				test,
				string.format("StudioTestService did not return after %d seconds", watchdogSeconds),
				elapsedMs
			)
		end
		if not ok then
			return failedResult(test, "Unexpected plugin runtime error: " .. tostring(report), elapsedMs)
		end
		return normalizeResult(test, report, elapsedMs)
	end

	local function recordResult(test, result)
		table.insert(renderedResults, result)
		history:add(test, result)
		renderResults()
		renderHistory()
	end

	runOne = function(test)
		if busy then
			return nil
		end
		setBusy(true)
		renderedResults = {}
		renderResults()
		status.Text = "Running " .. test.name .. "..."
		local result = execute(test)
		recordResult(test, result)
		setBusy(false)
		refreshTests()
		status.Text = result.passed and "Completed successfully" or "Completed with errors"
		return result
	end

	local function performProjectAction(action, runningText)
		if busy then
			return false
		end
		setBusy(true)
		status.Text = runningText
		local callOk, succeeded, message = pcall(action)
		setBusy(false)
		refreshTests()
		if not callOk then
			status.Text = "BloxQA project setup failed: " .. tostring(succeeded)
			return false
		end
		status.Text = tostring(message)
		return succeeded
	end

	refreshTests = function()
		gameplayTests, placeRuntimeError, projectInspection = resolvePlaceRuntime()
		if gameplayTests then
			tests, discoveryErrors = TestRegistry.discover(gameplayTests)
		else
			tests = {}
			discoveryErrors = {}
		end
		renderProjectState()
		renderDiagnostics()
		renderFilters()
		clearGenerated(testList, "BloxQATestRow")
		runButtons = {}

		local latest = history:getLatestByTestId()
		local layoutOrder = 0
		local lastCategory
		for _, test in ipairs(getVisibleTests()) do
			if test.category ~= lastCategory then
				lastCategory = test.category
				layoutOrder += 1
				local category = create("TextLabel", {
					Name = "Category",
					LayoutOrder = layoutOrder,
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					Text = test.category,
					TextColor3 = COLORS.muted,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = testList,
				})
				category:SetAttribute("BloxQATestRow", true)
			end

			layoutOrder += 1
			local row = create("Frame", {
				Name = test.id .. "Row",
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, 0, 0, 62),
				BackgroundColor3 = COLORS.surface,
				BorderSizePixel = 0,
				Parent = testList,
			})
			row:SetAttribute("BloxQATestRow", true)
			row:SetAttribute("TestId", test.id)
			row:SetAttribute("Category", test.category)
			row:SetAttribute("Mode", test.mode)
			row:SetAttribute("Players", test.players)
			rounded(row)

			create("TextLabel", {
				Name = "TestName",
				Size = UDim2.new(1, -82, 0, 24),
				Position = UDim2.fromOffset(10, 6),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansSemibold,
				Text = test.name,
				TextColor3 = COLORS.text,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})

			local recent = latest[test.id]
			local modePrefix = test.mode == "multiplayer"
				and string.format("%d Players · ", test.players)
				or ""
			create("TextLabel", {
				Name = "Latest",
				Size = UDim2.new(1, -82, 0, 20),
				Position = UDim2.fromOffset(10, 32),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Text = recent and string.format(
					"%s%s %s · %dms",
					modePrefix,
					recent.status == "PASS" and "✓" or "✕",
					recent.status,
					recent.durationMs
				) or (modePrefix .. "Not run yet"),
				TextColor3 = recent
					and (recent.status == "PASS" and COLORS.pass or COLORS.fail)
					or COLORS.muted,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})

			local button = create("TextButton", {
				Name = "Run",
				Size = UDim2.fromOffset(58, 30),
				Position = UDim2.new(1, -68, 0.5, -15),
				BackgroundColor3 = busy and COLORS.buttonDisabled or COLORS.button,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSansSemibold,
				Text = "Run",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				Active = not busy,
				AutoButtonColor = not busy,
				Parent = row,
			})
			rounded(button)
			button.Activated:Connect(function()
				task.spawn(runOne, test)
			end)
			runButtons[test.id] = button
		end

		if #discoveryErrors > 0 then
			layoutOrder += 1
			local warning = create("TextLabel", {
				Name = "DiscoveryWarning",
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = Color3.fromRGB(67, 58, 35),
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				Text = string.format(
					"⚠ %d invalid test module%s ignored. See Output for details.",
					#discoveryErrors,
					#discoveryErrors == 1 and "" or "s"
				),
				TextColor3 = COLORS.warning,
				TextSize = 13,
				TextWrapped = true,
				Parent = testList,
			})
			warning:SetAttribute("BloxQATestRow", true)
			rounded(warning)
			for _, discoveryError in ipairs(discoveryErrors) do
				warn(string.format(
					"[BloxQA] Invalid test module %s: %s",
					discoveryError.path,
					discoveryError.message
				))
			end
		end

		testList.Size = UDim2.new(1, 0, 0, math.max(34, testListLayout.AbsoluteContentSize.Y))
		if controllerError then
			status.Text = "Controller unavailable: " .. controllerError
		elseif projectInspection and projectInspection.state == "missing" then
			status.Text = "No BloxQA project detected"
		elseif placeRuntimeError then
			status.Text = "BloxQA project requires attention"
		elseif #discoveryErrors > 0 then
			status.Text = string.format(
				"Ready — %d valid, %d invalid test%s",
				#tests,
				#discoveryErrors,
				#discoveryErrors == 1 and "" or "s"
			)
		elseif not busy then
			status.Text = string.format(
				"Ready — %d test%s discovered%s",
				#tests,
				#tests == 1 and "" or "s",
				selectedCategory and (" · " .. selectedCategory .. " filter") or ""
			)
		end
	end

	local function runAll()
		if busy then
			return nil
		end
		refreshTests()
		local runList = getVisibleTests()
		setBusy(true)
		renderedResults = {}
		renderResults()

		for index, test in ipairs(runList) do
			status.Text = string.format("Running test %d/%d... %s", index, #runList, test.name)
			local result = execute(test)
			recordResult(test, result)
			if index < #runList then
				status.Text = string.format("Completed test %d/%d; preparing next test...", index, #runList)
				task.wait(1)
			end
		end

		setBusy(false)
		refreshTests()
		status.Text = #runList > 0 and "All visible tests completed" or "No valid tests discovered"
		return renderedResults
	end

	runAllButton.Activated:Connect(function()
		task.spawn(runAll)
	end)
	initializeButton.Activated:Connect(function()
		task.spawn(performProjectAction, ProjectInitializer.initialize, "Initializing BloxQA...")
	end)
	repairButton.Activated:Connect(function()
		task.spawn(performProjectAction, ProjectInitializer.repair, "Repairing BloxQA...")
	end)
	historyToggle.Activated:Connect(function()
		historyExpanded = not historyExpanded
		renderHistory()
	end)

	local refreshQueued = false
	local function scheduleRefresh()
		if refreshQueued then
			return
		end
		refreshQueued = true
		task.delay(0.2, function()
			refreshQueued = false
			if not busy then
				refreshTests()
			end
		end)
	end

	ReplicatedStorage.DescendantAdded:Connect(function(child)
		if child:IsA("ModuleScript") and child.Name:match("Test$") then
			local canReadSource, childSource = pcall(function()
				return child.Source
			end)
			if canReadSource and not childSource:match("%S") then
				local connection
				connection = child:GetPropertyChangedSignal("Source"):Connect(function()
					connection:Disconnect()
					scheduleRefresh()
				end)
				return
			end
		end
		scheduleRefresh()
	end)
	ReplicatedStorage.DescendantRemoving:Connect(scheduleRefresh)
	ServerScriptService.ChildAdded:Connect(scheduleRefresh)
	ServerScriptService.ChildRemoved:Connect(scheduleRefresh)

	local function syncToolbar()
		toolbarButton:SetActive(widget.Enabled)
	end
	local function togglePanel()
		widget.Enabled = not widget.Enabled
		return widget.Enabled
	end
	toolbarButton.Click:Connect(togglePanel)
	widget:GetPropertyChangedSignal("Enabled"):Connect(syncToolbar)
	syncToolbar()

	renderResults()
	renderHistory()
	refreshTests()

	local api = {}
	function api.TogglePanel()
		return togglePanel()
	end
	function api.ToggleHistory()
		historyExpanded = not historyExpanded
		renderHistory()
		return historyExpanded
	end
	function api.SetFilter(category)
		if category == nil or category == "All" then
			selectedCategory = nil
		else
			selectedCategory = tostring(category)
		end
		refreshTests()
		return api.GetSnapshot()
	end
	function api.RefreshTests()
		refreshTests()
		return api.GetSnapshot()
	end
	function api.RunTest(testId)
		refreshTests()
		for _, test in ipairs(tests) do
			if test.id == testId then
				return runOne(test)
			end
		end
		return {
			testId = tostring(testId),
			name = tostring(testId),
			status = "FAIL",
			passed = false,
			errorMessage = "Unknown or invalid discovered test: " .. tostring(testId),
			durationMs = 0,
		}
	end
	function api.RunAll()
		return runAll()
	end
	function api.InitializeProject()
		return performProjectAction(ProjectInitializer.initialize, "Initializing BloxQA...")
	end
	function api.RepairProject()
		return performProjectAction(ProjectInitializer.repair, "Repairing BloxQA...")
	end
	function api.GetSnapshot()
		local discovered = {}
		for index, test in ipairs(tests) do
			discovered[index] = {
				id = test.id,
				name = test.name,
				category = test.category,
				description = test.description,
				timeout = test.timeout,
				mode = test.mode,
				players = test.players,
			}
		end
		local errors = {}
		for index, discoveryError in ipairs(discoveryErrors) do
			errors[index] = {
				moduleName = discoveryError.moduleName,
				path = discoveryError.path,
				message = discoveryError.message,
			}
		end
		return {
			version = Version.string,
			projectState = projectInspection and projectInspection.state or "unknown",
			projectHealthy = projectInspection and projectInspection.healthy or false,
			projectRepairable = projectInspection and projectInspection.repairable or false,
			projectIssues = projectInspection and projectInspection.issues or {},
			runtimeVersion = ProjectInitializer.RUNTIME_VERSION,
			schemaVersion = ProjectInitializer.SCHEMA_VERSION,
			widgetEnabled = widget.Enabled,
			historyExpanded = historyExpanded,
			selectedCategory = selectedCategory or "All",
			visibleTestCount = #getVisibleTests(),
			diagnostics = diagnostics.Text,
			placeRuntimeInstalled = gameplayTests ~= nil and placeRuntimeError == nil,
			placeRuntimeError = placeRuntimeError,
			status = status.Text,
			summary = summary.Text,
			busy = busy,
			tests = discovered,
			discoveryErrors = errors,
			results = renderedResults,
			history = history:getAll(),
			persistence = history:getPersistenceStatus(),
		}
	end
	function api.Destroy()
		widget:Destroy()
		toolbarButton:Destroy()
		toolbar:Destroy()
	end

	return api
end

return PluginMain
