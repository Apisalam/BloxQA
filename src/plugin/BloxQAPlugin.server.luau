assert(plugin, "BloxQAPlugin must run from a real Roblox Studio plugin context")

local modules = script:WaitForChild("Modules")
local PluginMain = require(modules:WaitForChild("PluginMain"))

local ok, result = pcall(PluginMain.start, plugin)
if not ok then
	warn("[BloxQA] Global plugin failed to start: " .. tostring(result))
end

