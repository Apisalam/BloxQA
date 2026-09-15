local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildLocalRelease = {}

local DEFAULT_RELEASE_NOTES = [[
BloxQA 0.2.0-dev Developer Preview
- One-click, idempotent per-place runtime initialization
- Embedded runtime template with starter gameplay tests
- Missing, healthy, and incomplete/corrupt project diagnostics
- Runtime ownership and schema metadata for future migrations
]]

local INSTALL_INSTRUCTIONS = [[
1. Open Plugins > Manage Plugins and disable or uninstall the previous BloxQA local plugin.
2. Select this root Script in Studio Explorer (not its Modules folder and not the old BloxQA_0_1_0 Model).
3. Choose Plugins > Save as Local Plugin and name it BloxQA.
4. Confirm replacement if Studio asks, close every Studio window, and restart Studio.
5. Open a brand-new Baseplate and confirm the BloxQA toolbar and v0.2.0-dev panel appear.
6. Click Initialize BloxQA and confirm the two starter tests appear without reopening the panel.
7. Run the discovered starter tests in the initialized place.
See LOCAL_PLUGIN_RELEASE.md in the BloxQA project for details.
]]

local function addStringValue(parent, name, value)
	local item = Instance.new("StringValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

function BuildLocalRelease.build(version, options)
	options = options or {}
	assert(
		type(version) == "string"
			and (version:match("^%d+%.%d+%.%d+$") or version:match("^%d+%.%d+%.%d+%-%w[%w%.%-]*$")),
		"Version must use semantic versioning, with an optional prerelease suffix"
	)

	local bloxqa = ReplicatedStorage:WaitForChild("BloxQA")
	local currentVersion = bloxqa:GetAttribute("BloxQARuntimeVersion")
	assert(type(currentVersion) == "string", "ReplicatedStorage.BloxQA is missing BloxQARuntimeVersion metadata")
	assert(version == currentVersion, string.format(
		"Requested version %s does not match BloxQA.Version %s",
		version,
		currentVersion
	))

	local developmentSource = ServerStorage:WaitForChild("BloxQAGlobalPluginSource")
	assert(developmentSource:IsA("Script"), "BloxQAGlobalPluginSource must be a root Script")
	assert(developmentSource:GetAttribute("Version") == version, "BloxQAGlobalPluginSource Version attribute is not synchronized")
	assert(developmentSource:FindFirstChild("Modules"), "BloxQAGlobalPluginSource.Modules is required")

	local releases = ServerStorage:FindFirstChild("BloxQAReleases")
	if not releases then
		releases = Instance.new("Folder")
		releases.Name = "BloxQAReleases"
		releases.Parent = ServerStorage
	end

	local releaseName = "BloxQAPlugin_" .. version:gsub("[^%w]", "_")
	local existing = releases:FindFirstChild(releaseName)
	if existing then
		assert(options.replaceExisting == true, releaseName .. " already exists; pass replaceExisting = true")
		existing:Destroy()
	end

	local release = developmentSource:Clone()
	release.Name = releaseName
	release:SetAttribute("ArtifactType", "InstallableGlobalLocalPlugin")
	release:SetAttribute("ReleaseChannel", "DeveloperPreview")
	release:SetAttribute("Version", version)
	release:SetAttribute("PackageName", "BloxQA")
	release:SetAttribute("EntryPoint", true)
	release:SetAttribute("BuiltFrom", developmentSource:GetFullName())
	release:SetAttribute("BuiltAtUtc", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	release:SetAttribute("InstallHint", "Select this root Script, then choose Plugins > Save as Local Plugin")

	addStringValue(release, "VersionMarker", version)
	addStringValue(release, "ReleaseNotes", options.releaseNotes or DEFAULT_RELEASE_NOTES)
	addStringValue(release, "LocalInstallInstructions", INSTALL_INSTRUCTIONS)

	release.Parent = releases
	return release
end

return BuildLocalRelease

