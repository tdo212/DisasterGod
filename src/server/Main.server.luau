--!strict
-- Server bootstrap: initialise every service in dependency order, then start the loop.

local Services = script.Parent:WaitForChild("Services")

local function load(name: string): any
	return require(Services:WaitForChild(name) :: ModuleScript)
end

local order = {
	"PlayerDataService",
	"AudioService",
	"RagdollService",
	"QuestService",
	"RoleService",
	"EnvironmentService",
	"DestructionService",
	"MapService",
	"ScoringService",
	"DisasterService",
	"ShopService",
	"SpinService",
	"VoteService",
	"LobbyService",
	"MatchService",
	"MonetizationService",
}

for _, name in order do
	local service = load(name)
	if service.Init then
		service.Init()
	end
end

load("MatchService").Start()
