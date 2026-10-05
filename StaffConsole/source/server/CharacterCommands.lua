--// Server-owned flight and freeze for staff commands; rank checks stay in Monarch.Admin, flight input is rechecked here
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ranks = require(script.Parent.Ranks)
local Rules = require(script.Parent.Rules)

local Commands = {}
local flights, frozen = {}, {}
local SPEED = 48
local started = false

local function characterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return character, humanoid, root
end

function Commands.IsFlying(player)
	return flights[player] ~= nil
end

--// STOP: removes the movers, restores the humanoid and gives the character back to its player
local function stopFlight(player)
	local state = flights[player]
	flights[player] = nil
	player:SetAttribute("MonarchFlying", false)
	if not state then return end
	state.velocity:Destroy()
	state.orientation:Destroy()
	state.attachment:Destroy()
	if state.humanoid.Parent then
		state.humanoid.PlatformStand = state.platformStand
		state.humanoid.AutoRotate = state.autoRotate
	end
	if state.root.Parent then
		state.root.AssemblyLinearVelocity = Vector3.zero
		pcall(function() state.root:SetNetworkOwner(player) end)
	end
end

function Commands.SetFly(player, on)
	if not on then
		stopFlight(player)
		return true, "Flight off"
	end
	if flights[player] then return true, "Flight already on" end
	local character, humanoid, root = characterParts(player)
	if not character then return false, "You need a living character" end
	if root.Anchored or frozen[player] then return false, "Unfreeze before flying" end
	local canOwn = root:CanSetNetworkOwnership()
	if not canOwn then return false, "Cannot control this character's flight" end
	root:SetNetworkOwner(nil)
	local attachment = Instance.new("Attachment")
	attachment.Name = "MonarchFlightAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "MonarchFlightVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.max(root.AssemblyMass * 2000, 100000)
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "MonarchFlightOrientation"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = 1000000
	orientation.Responsiveness = 15
	orientation.CFrame = root.CFrame.Rotation
	orientation.Parent = root
	flights[player] = {
		character = character, humanoid = humanoid, root = root,
		attachment = attachment, velocity = velocity, orientation = orientation,
		autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand,
		lastInput = 0, lastPacket = 0,
	}
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	player:SetAttribute("MonarchFlying", true)
	return true, "Flight on / WASD, Space up, Ctrl down"
end

function Commands.SetFrozen(player, on)
	if not on then
		local state = frozen[player]
		frozen[player] = nil
		player:SetAttribute("MonarchFrozen", false)
		if not state then return true, player.Name .. " is not frozen" end
		if state.root.Parent then state.root.Anchored = state.anchored end
		return true, "Unfroze " .. player.Name
	end
	if frozen[player] then return true, player.Name .. " is already frozen" end
	local character, _, root = characterParts(player)
	if not character then return false, "That player needs a living character" end
	stopFlight(player)
	frozen[player] = { character = character, root = root, anchored = root.Anchored }
	root.Anchored = true
	player:SetAttribute("MonarchFrozen", true)
	return true, "Froze " .. player.Name
end

function Commands.Clear(player)
	stopFlight(player)
	Commands.SetFrozen(player, false)
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y
		and value.Z == value.Z and value.Magnitude < 100000
end

--// INIT: the flight input remote, at most 30 packets a second, ignored unless the sender is flying and still allowed to fly
function Commands.Init()
	if started then return end
	started = true
	local remotes = ReplicatedStorage.MonarchShared.Remotes
	local remote = Instance.new("RemoteEvent")
	remote.Name = "AdminFlightInput"
	remote.Parent = remotes
	remote.OnServerEvent:Connect(function(player, direction, look)
		local state = flights[player]
		if not state then return end
		local now = os.clock()
		if now - state.lastPacket < 1 / 30 then return end
		state.lastPacket = now
		if not Rules.Can(Ranks.Get(player), "setFly") then stopFlight(player); return end
		if not finiteVector(direction) or not finiteVector(look) then return end
		state.lastInput = now
		state.velocity.VectorVelocity = (direction.Magnitude > 1 and direction.Unit or direction) * SPEED
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			state.orientation.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
	end)
	local function bind(player)
		player.CharacterRemoving:Connect(function() Commands.Clear(player) end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	Players.PlayerRemoving:Connect(Commands.Clear)
	RunService.Heartbeat:Connect(function()
		for player, state in pairs(flights) do
			if player.Character ~= state.character or not state.root.Parent or state.humanoid.Health <= 0
				or not Rules.Can(Ranks.Get(player), "setFly") then
				stopFlight(player)
			elseif os.clock() - state.lastInput > 0.4 then
				state.velocity.VectorVelocity = Vector3.zero
			end
		end
		for player, state in pairs(frozen) do
			local humanoid = state.character:FindFirstChildOfClass("Humanoid")
			if player.Character ~= state.character or not humanoid or humanoid.Health <= 0 then
				Commands.SetFrozen(player, false)
			end
		end
	end)
end

return Commands
