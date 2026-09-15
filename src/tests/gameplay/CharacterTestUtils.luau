local Players = game:GetService("Players")

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

