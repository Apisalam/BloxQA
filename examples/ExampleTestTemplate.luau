-- BloxQA test authoring template.
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

