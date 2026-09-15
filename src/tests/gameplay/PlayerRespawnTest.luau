local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

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

