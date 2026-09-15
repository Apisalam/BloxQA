local CharacterTestUtils = require(script.Parent:WaitForChild("CharacterTestUtils"))

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

