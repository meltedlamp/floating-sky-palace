--[[
	ParkourClient  (LocalScript)  ->  StarterPlayer > StarterPlayerScripts > ParkourClient

	Assassin's-Creed-style free-running for the Floating Sky Palace.
	Everything in the world is climbable unless it is non-collidable or tagged "NoClimb".

	CONTROLS
	  Hold Shift ...... free-run (sprint). Run at any wall to climb it, run at a low wall to vault it,
	                    jump at a wall at an angle to wall-run along it.
	  WASD / stick .... while climbing: move along the wall. Push up at a ledge to pull yourself over.
	  Space ........... jump. On a wall: leap up (W), sideways (A/D) or kick off backwards (S / no input).
	                    While falling you automatically catch any wall or ledge you touch.
	  Ctrl / C ........ let go of a wall, drop from a zipline, or drop off an edge and hang from it.
	  E ............... Leap of Faith (at an edge with hay below), Synchronise (on a viewpoint perch),
	                    ride a zipline (next to its start post).
	  Hold Shift when landing from a high fall to roll and take no damage.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local folder = ReplicatedStorage:WaitForChild("Parkour")
local Config = require(folder:WaitForChild("ParkourConfig"))
local remote = folder:WaitForChild("ParkourEvent")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local UP = Vector3.yAxis
local ZERO = Vector3.zero
local HS = Enum.HumanoidStateType

---------------------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------------------
local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.zAxis
end

local function isWall(hit)
	return hit ~= nil and math.abs(hit.Normal.Y) < Config.WallMaxNormalY
end

local function keyIn(list, key)
	for _, k in ipairs(list) do
		if k == key then return true end
	end
	return false
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true

local function refreshFilters()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	rayParams.FilterDescendantsInstances = list
	overlapParams.FilterDescendantsInstances = list
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(refreshFilters) end)
for _, p in ipairs(Players:GetPlayers()) do p.CharacterAdded:Connect(refreshFilters) end

local function cast(origin, dir)
	local hit = Workspace:Raycast(origin, dir, rayParams)
	if hit and CollectionService:HasTag(hit.Instance, "NoClimb") then return nil end
	return hit
end

local function tweenTo(part, time, cf, style, direction)
	local t = TweenService:Create(part, TweenInfo.new(time, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.Out), { CFrame = cf })
	t:Play()
	t.Completed:Wait()
end

-- movement input straight from the control module (works for keyboard, gamepad and touch)
local controls
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then controls = module:GetControls() end
end)

local function moveVector()
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" then return v end
	end
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then z -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then z += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then x -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then x += 1 end
	return Vector3.new(x, 0, z)
end

---------------------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------------------
local hud = {}
do
	local gui = Instance.new("ScreenGui")
	gui.Name = "ParkourHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5

	local function label(name, pos, size, textSize, anchor, xAlign)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
		l.Font = Enum.Font.GothamBold
		l.TextSize = textSize
		l.TextColor3 = Color3.fromRGB(245, 240, 225)
		l.TextStrokeTransparency = 0.4
		l.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
		l.Text = ""
		l.Parent = gui
		return l
	end

	hud.prompt = label("Prompt", UDim2.fromScale(0.5, 0.86), UDim2.fromScale(0.6, 0.05), 22)
	hud.banner = label("Banner", UDim2.fromScale(0.5, 0.32), UDim2.fromScale(0.8, 0.08), 44)
	hud.banner.Font = Enum.Font.Antique
	hud.banner.TextTransparency = 1
	hud.banner.TextStrokeTransparency = 1
	hud.sub = label("Sub", UDim2.fromScale(0.5, 0.385), UDim2.fromScale(0.8, 0.05), 20)
	hud.sub.TextTransparency = 1
	hud.sub.TextStrokeTransparency = 1
	hud.counter = label("Counter", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(300, 28), 20, Vector2.new(1, 0), Enum.TextXAlignment.Right)
	hud.controls = label("Controls", UDim2.new(1, -24, 0, 58), UDim2.fromOffset(340, 190), 14, Vector2.new(1, 0), Enum.TextXAlignment.Right)
	hud.controls.Font = Enum.Font.Gotham
	hud.controls.TextYAlignment = Enum.TextYAlignment.Top
	hud.controls.TextColor3 = Color3.fromRGB(225, 225, 230)
	hud.controls.Text = table.concat({
		"FREE-RUN  hold Shift (run at walls to climb)",
		"VAULT / WALL-RUN  sprint at low walls / angled walls",
		"CLIMB LEAP  Space + W / A / D   KICK OFF  Space",
		"DROP / HANG FROM EDGE  Ctrl or C",
		"INTERACT  E  (viewpoint · zipline · leap of faith)",
		"ROLL  hold Shift as you land",
	}, "\n")

	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(160, 20, 20)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 0
	vignette.Parent = gui
	hud.vignette = vignette

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setPrompt(text)
	hud.prompt.Text = text or ""
end

local bannerToken = 0
local function showBanner(title, sub, duration)
	bannerToken += 1
	local token = bannerToken
	hud.banner.Text = title or ""
	hud.sub.Text = sub or ""
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(hud.banner, info, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	TweenService:Create(hud.sub, info, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	task.delay(duration or 2.5, function()
		if token ~= bannerToken then return end
		local out = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(hud.banner, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(hud.sub, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function flashVignette(strength)
	hud.vignette.BackgroundTransparency = 1 - math.clamp(strength, 0, 0.9)
	TweenService:Create(hud.vignette, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- camera shake, applied after the camera has updated
local shake = 0
RunService:BindToRenderStep("ParkourCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		local t = os.clock() * 40
		camera.CFrame = camera.CFrame * CFrame.Angles(math.sin(t) * shake * 0.03, math.cos(t * 1.3) * shake * 0.03, 0)
		shake = math.max(0, shake - dt * 3)
	end
end)

-- viewpoint counter
local syncedIds = {}
local function viewpointTotal()
	local ids = {}
	for _, p in ipairs(CollectionService:GetTagged("Viewpoint")) do
		ids[p:GetAttribute("Id") or p.Name] = true
	end
	local n = 0
	for _ in pairs(ids) do n += 1 end
	return n
end
local function updateCounter()
	local n = 0
	for _ in pairs(syncedIds) do n += 1 end
	hud.counter.Text = ("VIEWPOINTS  %d / %d"):format(n, viewpointTotal())
end
updateCounter()

---------------------------------------------------------------------------------------
-- character state
---------------------------------------------------------------------------------------
local char, hum, root, animator
local mover, gyro, att
local climbTrack, fallTrack, runTrack

local state = "Ground"      -- Ground | Climb | Mantle | Vault | WallRun | Roll | Zipline | Dive | Sync | Dead
local sprint = false
local wall = { n = Vector3.zAxis, part = nil }
local wallRun = nil
local zip = nil
local dive = nil
local peakY = 0
local regrabBlockUntil = 0
local mantleRetryAt = 0
local lastJumpRequest = 0
local promptClock = 0

local function rootHeight()
	return hum.HipHeight + root.Size.Y / 2
end

local function grounded()
	return hum.FloorMaterial ~= Enum.Material.Air
end

local function hayNearby(radius)
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(root.Position, radius or 7, overlapParams)) do
		if CollectionService:HasTag(part, "HayBale") then return part end
	end
	return nil
end

local function hayBurst(hay)
	local emitter = hay:FindFirstChild("HayBurst")
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "HayBurst"
		emitter.Color = ColorSequence.new(Color3.fromRGB(222, 196, 110))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.1) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Acceleration = Vector3.new(0, -30, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-200, 200)
		emitter.Rate = 0
		emitter.Parent = hay
	end
	emitter:Emit(60)
end

---------------------------------------------------------------------------------------
-- state transitions
---------------------------------------------------------------------------------------
local function enterPhysics()
	hum.AutoRotate = false
	hum:ChangeState(HS.Physics)
end

-- back to normal humanoid control. `velocity` is applied; `standing` skips the free-fall state.
local function release(velocity, standing)
	state = "Ground"
	wallRun, zip, dive = nil, nil, nil
	mover.Enabled = false
	gyro.Enabled = false
	root.Anchored = false
	climbTrack:Stop(0.1)
	fallTrack:Stop(0.1)
	runTrack:Stop(0.1)
	local look = flat(root.CFrame.LookVector)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	hum.AutoRotate = true
	peakY = root.Position.Y
	if standing then
		hum:ChangeState(HS.Running)
	else
		hum:ChangeState(HS.Freefall)
	end
	root.AssemblyLinearVelocity = velocity or ZERO
	regrabBlockUntil = os.clock() + 0.2
	setPrompt("")
end

local function startClimb(hit)
	state = "Climb"
	wall.n = flat(hit.Normal)
	wall.part = hit.Instance
	enterPhysics()
	root.AssemblyLinearVelocity = ZERO
	mover.VectorVelocity = ZERO
	mover.Enabled = true
	gyro.CFrame = CFrame.lookAt(ZERO, -wall.n)
	gyro.Enabled = true
	fallTrack:Stop()
	climbTrack:Play(0.15)
	climbTrack:AdjustSpeed(0)
	setPrompt("Space  leap   ·   Ctrl  let go")
end

local function standClear(cf)
	local parts = Workspace:GetPartBoundsInBox(cf * CFrame.new(0, 0.3, 0), Vector3.new(1.6, 4.4, 1.6), overlapParams)
	return #parts == 0
end

local function doMantle(ledgePos)
	state = "Mantle"
	mover.Enabled = false
	gyro.Enabled = false
	climbTrack:AdjustSpeed(1.6)

	local look = -wall.n
	local rot = CFrame.lookAt(ZERO, look).Rotation
	local standY = ledgePos.Y + rootHeight() + 0.15
	local target = CFrame.new(Vector3.new(ledgePos.X, standY, ledgePos.Z) + look * 1.2) * rot
	if not standClear(target) then
		target = CFrame.new(Vector3.new(ledgePos.X, standY, ledgePos.Z) + wall.n * 0.2) * rot
		if not standClear(target) then
			-- not enough room on top: keep climbing and try again shortly
			state = "Climb"
			mover.Enabled = true
			gyro.Enabled = true
			mantleRetryAt = os.clock() + 0.35
			return
		end
	end

	root.Anchored = true
	local rise = CFrame.new(root.Position.X, standY + 0.4, root.Position.Z) * rot
	tweenTo(root, Config.MantleTime * 0.55, rise)
	if state ~= "Mantle" then return end
	tweenTo(root, Config.MantleTime * 0.45, target, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if state ~= "Mantle" then return end
	root.Anchored = false
	release(look * 4, true)
end

local function doVault(dir, topY, facePos, landY)
	state = "Vault"
	enterPhysics()
	root.Anchored = true
	local rot = CFrame.lookAt(ZERO, dir).Rotation
	local rh = rootHeight()
	local over = CFrame.new(Vector3.new(facePos.X, topY + rh + 0.3, facePos.Z) + dir * 1.5) * rot
	local land = CFrame.new(Vector3.new(facePos.X, landY + rh + 0.1, facePos.Z) + dir * 4.5) * rot
	climbTrack:Play(0.1)
	climbTrack:AdjustSpeed(2)
	tweenTo(root, 0.22, over)
	if state ~= "Vault" then return end
	tweenTo(root, 0.24, land, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if state ~= "Vault" then return end
	root.Anchored = false
	release(dir * Config.SprintSpeed * 0.8, true)
end

local function tryVault(dir)
	local pos = root.Position
	local feetY = pos.Y - rootHeight()
	local low = cast(pos - UP * 1.0, dir * 3.5)
	local high = cast(pos + UP * 1.6, dir * 3.5)
	if not (low and isWall(low)) or high then return false end
	local top = cast(low.Position + dir * 0.6 + UP * 5, -UP * 6)
	if not (top and top.Normal.Y > 0.6) then return false end
	local h = top.Position.Y - feetY
	if h < Config.VaultMinHeight or h > Config.VaultMaxHeight then return false end
	local far = cast(low.Position + dir * 4.5 + UP * 5, -UP * (h + 14))
	if far and far.Position.Y > top.Position.Y - 1 then return false end -- too thick, that's a roof not a wall
	task.spawn(doVault, dir, top.Position.Y, low.Position, far and far.Position.Y or feetY)
	return true
end

local function startWallRun(hit, moveDir)
	local n = flat(hit.Normal)
	local along = moveDir - n * moveDir:Dot(n)
	if along.Magnitude < 0.2 then return false end
	state = "WallRun"
	wallRun = { n = n, along = along.Unit, t = 0 }
	enterPhysics()
	mover.Enabled = true
	gyro.CFrame = CFrame.lookAt(ZERO, wallRun.along)
	gyro.Enabled = true
	runTrack:Play(0.1)
	runTrack:AdjustSpeed(1.4)
	return true
end

local function doRoll()
	state = "Roll"
	local md = hum.MoveDirection
	local dir = md.Magnitude > 0.2 and md.Unit or flat(root.CFrame.LookVector)
	enterPhysics()
	mover.Enabled = true
	local rot = CFrame.lookAt(ZERO, dir).Rotation
	local t = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		if state ~= "Roll" then conn:Disconnect() return end
		local ang = (t / Config.RollTime) * math.pi * 2
		root.CFrame = CFrame.new(root.Position) * rot * CFrame.Angles(-ang, 0, 0)
		mover.VectorVelocity = dir * Config.RollSpeed * (1 - 0.5 * t / Config.RollTime) - UP * 6
		if t >= Config.RollTime then
			conn:Disconnect()
			root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
			release(dir * 12, true)
		end
	end)
end

local function handleLanding(fallDist)
	if fallDist < Config.SafeFall then return end
	local hay = hayNearby(7)
	if hay then
		hayBurst(hay)
		shake = 0.6
		return
	end
	if sprint and fallDist < Config.RollFall then
		doRoll()
		shake = 0.5
		return
	end
	local dmg = (fallDist - Config.SafeFall) * Config.FallDamagePerStud
	if fallDist >= Config.DeathFall then dmg = 1000 end
	remote:FireServer("FallDamage", dmg)
	flashVignette(math.clamp(dmg / 60, 0.3, 0.9))
	shake = 1.2
	if dmg < 1000 then setPrompt("Hold Shift as you land to roll") end
end

---------------------------------------------------------------------------------------
-- climbing
---------------------------------------------------------------------------------------
local function climbInputs()
	local mv = moveVector()
	local upIn = -mv.Z
	local camSign = camera.CFrame.LookVector:Dot(-wall.n) >= 0 and 1 or -1
	return upIn, mv.X * camSign
end

local function climbUpdate(dt)
	local HANG = Config.HangDistance
	local probe = HANG + 2.0
	local upIn, sideIn = climbInputs()
	local n = wall.n
	local pos = root.Position

	local chest = cast(pos + n * 0.6, -n * probe)
	local head = cast(pos + UP * 2.6 + n * 0.6, -n * probe)
	local feet = cast(pos - UP * 2.0 + n * 0.6, -n * probe)

	-- the surface has flattened out under us (top of a dome): stand up
	if chest and chest.Normal.Y > Config.WallMaxNormalY and chest.Normal.Y > 0 then
		release(nil, true)
		return
	end

	-- hold on to whichever wall surface is closest (a cornice above us pushes us outward instead of trapping us)
	local hold
	local function consider(hit)
		if hit and isWall(hit) then
			if not hold or (hit.Position - pos):Dot(-n) < (hold.Position - pos):Dot(-n) then hold = hit end
		end
	end
	consider(chest)
	consider(head)
	if not hold then consider(feet) end

	-- pulling up onto a ledge
	if upIn > 0.2 and not head and os.clock() > mantleRetryAt then
		local ledge = cast(pos + UP * 4.2 - n * (HANG + 1.0), -UP * 5.5)
		if ledge and ledge.Normal.Y > 0.6 and ledge.Position.Y > pos.Y - 1.5 then
			task.spawn(doMantle, ledge.Position)
			return
		end
		if not chest then
			-- hanging from the very top edge; is there a higher wall set back from us (stepped cliffs)?
			local deeper = cast(pos + UP * 2.6 + n * 0.6, -n * (HANG + 5))
			if deeper and isWall(deeper) then
				local nn = flat(deeper.Normal)
				local cf = CFrame.new(Vector3.new(deeper.Position.X, pos.Y + 1.0, deeper.Position.Z) + nn * HANG) * CFrame.lookAt(ZERO, -nn).Rotation
				if standClear(cf) then
					wall.n = nn
					root.CFrame = cf
					return
				end
			end
		end
	end

	if not hold then
		local ledge = cast(pos + UP * 0.5 - n * (HANG + 1.0), -UP * 4.5)
		if ledge and ledge.Normal.Y > 0.6 and os.clock() > mantleRetryAt then
			task.spawn(doMantle, ledge.Position)
		else
			release()
		end
		return
	end

	wall.n = flat(hold.Normal)
	wall.part = hold.Instance
	n = wall.n
	local right = (-n):Cross(UP).Unit
	if hold == feet then upIn = math.min(upIn, 0) end

	-- sideways: is there still wall at the next position? handle corners
	if math.abs(sideIn) > 0.1 then
		local s = math.sign(sideIn)
		local nextPos = pos + right * s * 1.3
		local inner = cast(pos, right * s * 1.8)
		if inner and isWall(inner) then
			wall.n = flat(inner.Normal)
			n = wall.n
			right = (-n):Cross(UP).Unit
		else
			local ahead = cast(nextPos + n * 0.6, -n * probe)
			if not (ahead and isWall(ahead)) then
				local corner = cast(nextPos - n * (HANG + 1.2), -right * s * 2.6)
				if corner and isWall(corner) then
					wall.n = flat(corner.Normal)
					root.CFrame = CFrame.new(Vector3.new(corner.Position.X, pos.Y, corner.Position.Z) + wall.n * HANG)
						* CFrame.lookAt(ZERO, -wall.n).Rotation
					n = wall.n
					right = (-n):Cross(UP).Unit
				else
					sideIn = 0
				end
			end
		end
	end

	-- climbing down onto the ground
	if upIn < -0.1 then
		local floor = cast(pos, -UP * (rootHeight() + 0.6))
		if floor then
			release(nil, true)
			return
		end
	end

	local desired = UP * upIn + right * sideIn
	if desired.Magnitude > 1 then desired = desired.Unit end
	local vel = desired * Config.ClimbSpeed
	local err = (hold.Position + n * HANG - pos):Dot(n)
	vel += n * math.clamp(err * 10, -20, 20)
	mover.VectorVelocity = vel
	gyro.CFrame = CFrame.lookAt(ZERO, -n)
	climbTrack:AdjustSpeed(desired.Magnitude > 0.1 and 1.2 or 0)
end

local function climbJump()
	local upIn, sideIn = climbInputs()
	local n = wall.n
	local right = (-n):Cross(UP).Unit
	if upIn > 0.3 then
		release(UP * Config.WallJumpUp + (-n) * 3)
		regrabBlockUntil = os.clock() + 0.25
	elseif math.abs(sideIn) > 0.3 then
		release(right * math.sign(sideIn) * Config.SideLeap + UP * 30)
		regrabBlockUntil = os.clock() + 0.25
	else
		release(n * Config.WallJumpBack + UP * 28)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + n)
		regrabBlockUntil = os.clock() + 0.45
	end
end

---------------------------------------------------------------------------------------
-- wall run
---------------------------------------------------------------------------------------
local function wallRunUpdate(dt)
	local w = wallRun
	w.t += dt
	local chest = cast(root.Position + w.n * 0.6, -w.n * (Config.HangDistance + 2))
	if w.t > Config.WallRunTime or not (chest and isWall(chest)) or moveVector().Magnitude < 0.2 then
		release(w.along * 18 + UP * 5)
		return
	end
	w.n = flat(chest.Normal)
	w.along = (w.along - w.n * w.along:Dot(w.n)).Unit
	local vy = 12 - (w.t / Config.WallRunTime) * 30
	local err = (chest.Position + w.n * Config.HangDistance - root.Position):Dot(w.n)
	mover.VectorVelocity = w.along * Config.WallRunSpeed + UP * vy + w.n * math.clamp(err * 10, -20, 20)
	local lean = (w.along:Cross(UP)):Dot(w.n) > 0 and -0.35 or 0.35
	gyro.CFrame = CFrame.lookAt(ZERO, w.along) * CFrame.Angles(0, 0, lean)
	if cast(root.Position, -UP * (rootHeight() + 0.3)) then
		release(w.along * 16, true)
	end
end

local function wallRunJump()
	local w = wallRun
	release(w.n * 22 + w.along * 18 + UP * 38)
	regrabBlockUntil = os.clock() + 0.3
end

---------------------------------------------------------------------------------------
-- ziplines
---------------------------------------------------------------------------------------
local function ropeEnds(model)
	local a = model:FindFirstChild("StartAnchor")
	local b = model:FindFirstChild("EndAnchor")
	if a and b then return a.Position, b.Position end
	return nil
end

local function nearbyZipline()
	local best, bestD
	for _, model in ipairs(CollectionService:GetTagged("Zipline")) do
		local a = ropeEnds(model)
		if a then
			local d = (a - root.Position).Magnitude
			if d < Config.ZiplineGrabRange and (not bestD or d < bestD) then
				best, bestD = model, d
			end
		end
	end
	return best
end

local function startZipline(model)
	local a, b = ropeEnds(model)
	if not a then return end
	state = "Zipline"
	local dir = (b - a).Unit
	zip = { a = a, b = b, dir = dir, len = (b - a).Magnitude, s = Config.ZiplineStartOffset, speed = 8 }
	enterPhysics()
	root.Anchored = true
	climbTrack:Play(0.1)
	climbTrack:AdjustSpeed(0)
	setPrompt("Space  jump off   ·   Ctrl  drop")
end

local function zipRelease(forward)
	local z = zip
	root.Anchored = false
	local v = forward and (flat(z.dir) * z.speed * 0.7 + UP * 12) or Vector3.new(0, -5, 0)
	release(v)
	regrabBlockUntil = os.clock() + 0.3
end

local function zipUpdate(dt)
	local z = zip
	z.speed = math.min(Config.ZiplineSpeed, z.speed + Config.ZiplineAccel * dt)
	z.s += z.speed * dt
	if z.s >= z.len - 2 then
		zipRelease(true)
		return
	end
	local p = z.a + z.dir * z.s - UP * Config.ZiplineHang
	root.CFrame = CFrame.lookAt(p, p + flat(z.dir))
end

---------------------------------------------------------------------------------------
-- leap of faith
---------------------------------------------------------------------------------------
local function findLeapTarget()
	local look = flat(root.CFrame.LookVector)
	local pos = root.Position
	-- there has to be a real drop right in front of us
	if cast(pos + look * 3, -UP * 25) then return nil end
	local best, bestScore
	for _, hay in ipairs(CollectionService:GetTagged("HayBale")) do
		local d = hay.Position - pos
		local horiz = Vector3.new(d.X, 0, d.Z)
		local drop = -d.Y
		if drop > Config.DiveMinDrop and horiz.Magnitude < Config.DiveSearchRadius and horiz.Magnitude > 1 and horiz.Unit:Dot(look) > 0.25 then
			local score = horiz.Magnitude - drop * 0.15
			if not bestScore or score < bestScore then
				best, bestScore = hay, score
			end
		end
	end
	return best
end

local function endDive()
	local d = dive
	gyro.Enabled = false
	fallTrack:Stop()
	local hay = hayNearby(7)
	local fallDist = peakY - root.Position.Y
	if hay then
		root.CFrame = CFrame.lookAt(Vector3.new(root.Position.X, hay.Position.Y + hay.Size.Y / 2 + rootHeight(), root.Position.Z), root.Position + d.dir)
		release(ZERO, true)
		hayBurst(hay)
		shake = 0.8
		showBanner("LEAP OF FAITH", "Synchronised landing", 2.5)
	else
		root.CFrame = CFrame.lookAt(root.Position + UP * 0.5, root.Position + UP * 0.5 + d.dir)
		release(ZERO, true)
		handleLanding(fallDist)
	end
end

local function startDive(target)
	local pos = root.Position
	local g = Workspace.Gravity
	local aim = target.Position + UP * (target.Size.Y / 2 + 1)
	local d = aim - pos
	local horiz = Vector3.new(d.X, 0, d.Z)
	local T = math.sqrt(2 * (-d.Y + 10) / g)
	local vxz = horiz / T
	local vy = (d.Y + 0.5 * g * T * T) / T

	state = "Dive"
	dive = { t = 0, dir = horiz.Unit }
	peakY = pos.Y
	enterPhysics()
	root.AssemblyLinearVelocity = vxz + UP * vy
	gyro.CFrame = CFrame.lookAt(ZERO, dive.dir)
	gyro.Enabled = true
	fallTrack:Play(0.1)
	shake = 0.3
	setPrompt("")
end

local function diveUpdate(dt)
	local d = dive
	d.t += dt
	peakY = math.max(peakY, root.Position.Y)
	local pitch = -math.min(d.t * 2.2, 3.0)   -- arms out, head first, then over onto your back
	gyro.CFrame = CFrame.lookAt(ZERO, d.dir) * CFrame.Angles(pitch, 0, 0)
	if d.t > 0.25 then
		local touching = #Workspace:GetPartBoundsInRadius(root.Position, 2.6, overlapParams) > 0
		if touching or root.AssemblyLinearVelocity.Magnitude < 2 then
			endDive()
		end
	end
end

---------------------------------------------------------------------------------------
-- viewpoints
---------------------------------------------------------------------------------------
local function standingOnViewpoint()
	local hit = cast(root.Position, -UP * (rootHeight() + 1.5))
	if not hit then return nil end
	local inst = hit.Instance
	while inst and inst ~= Workspace do
		if CollectionService:HasTag(inst, "Viewpoint") then return inst end
		inst = inst.Parent
	end
	return nil
end

local function syncPulse(origin)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 240, 200)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(4, 4, 4)
	ring.CFrame = CFrame.new(origin)
	CollectionService:AddTag(ring, "NoClimb")
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(500, 500, 500), Transparency = 1 }):Play()
	task.delay(2.5, function() ring:Destroy() end)
end

local function synchronize(perch)
	local id = perch:GetAttribute("Id") or perch.Name
	local title = perch:GetAttribute("Title") or id
	state = "Sync"
	root.Anchored = true
	camera.CameraType = Enum.CameraType.Scriptable
	local center = root.Position
	local startCF = camera.CFrame
	showBanner("VIEWPOINT SYNCHRONISED", title, Config.SyncDuration)
	syncPulse(center)

	local t = 0
	while t < Config.SyncDuration and state == "Sync" do
		local dt = RunService.RenderStepped:Wait()
		t += dt
		local f = math.min(t / Config.SyncDuration, 1)
		local ang = -0.6 + f * 2.6
		local radius = 26 + f * 18
		local height = 8 + f * 14
		local eye = center + Vector3.new(math.cos(ang) * radius, height, math.sin(ang) * radius)
		local target = CFrame.lookAt(eye, center + UP * 3)
		local blend = math.min(t / 0.6, 1)
		camera.CFrame = startCF:Lerp(target, blend)
	end

	camera.CameraType = Enum.CameraType.Custom
	root.Anchored = false
	if state == "Sync" then
		state = "Ground"
		hum:ChangeState(HS.Running)
	end
	if not syncedIds[id] then
		syncedIds[id] = true
		remote:FireServer("Sync", id)
		updateCounter()
		for _, p in ipairs(CollectionService:GetTagged("Viewpoint")) do
			if (p:GetAttribute("Id") or p.Name) == id then
				for _, d in ipairs(p.Parent:GetDescendants()) do
					if d:IsA("BasePart") and d.Name == "Eagle" then
						d.Material = Enum.Material.Neon
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------
-- ground state: sprinting, auto-climb, vault, wall-run, ledge catch, prompts
---------------------------------------------------------------------------------------
local function updatePrompt(onGround)
	if not onGround then
		setPrompt("")
		return
	end
	local vp = standingOnViewpoint()
	if vp then
		local id = vp:GetAttribute("Id") or vp.Name
		setPrompt(syncedIds[id] and "Viewpoint already synchronised" or "E  Synchronise viewpoint")
		return
	end
	if nearbyZipline() then
		setPrompt("E  Ride zipline")
		return
	end
	if findLeapTarget() then
		setPrompt("E  Leap of Faith")
		return
	end
	setPrompt("")
end

local function groundUpdate(dt)
	local hs = hum:GetState()
	local onGround = grounded()

	local targetSpeed = sprint and Config.SprintSpeed or Config.WalkSpeed
	if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
	local targetFov = (sprint and hum.MoveDirection.Magnitude > 0.1) and 80 or 70
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 6)

	promptClock += dt
	if promptClock > 0.15 then
		promptClock = 0
		updatePrompt(onGround)
	end

	local inAir = hs == HS.Freefall or hs == HS.Jumping
	if inAir then peakY = math.max(peakY, root.Position.Y) end
	if os.clock() < regrabBlockUntil then return end

	local md = hum.MoveDirection
	local moving = md.Magnitude > 0.2
	local dir = moving and md.Unit or flat(root.CFrame.LookVector)

	if onGround and sprint and moving then
		if tryVault(dir) then return end
		local hit = cast(root.Position + UP * 0.5, dir * Config.ClimbReach)
		if hit and isWall(hit) and (-flat(hit.Normal)):Dot(dir) > 0.75 then
			startClimb(hit)
			return
		end
	end

	if inAir then
		local vel = root.AssemblyLinearVelocity
		local look = flat(root.CFrame.LookVector)
		for _, d in ipairs({ dir, look, -look }) do
			local hitC = cast(root.Position + UP * 0.5, d * Config.ClimbReach)
			local hitH = cast(root.Position + UP * 2.4, d * Config.ClimbReach)
			local hit = (hitC and isWall(hitC) and hitC) or (hitH and isWall(hitH) and hitH)
			if hit then
				local n = flat(hit.Normal)
				if d == dir and sprint and moving and vel.Y > -5 then
					local facing = (-n):Dot(dir)
					if facing > 0.15 and facing < 0.8 and startWallRun(hit, dir) then return end
				end
				if vel.Y < 20 then
					startClimb(hit)
					return
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------
-- input
---------------------------------------------------------------------------------------
local function onJumpRequest()
	if not hum or hum.Health <= 0 then return end
	local now = os.clock()
	if now - lastJumpRequest < 0.2 then return end
	lastJumpRequest = now
	if state == "Climb" then
		climbJump()
	elseif state == "WallRun" then
		wallRunJump()
	elseif state == "Zipline" then
		zipRelease(true)
	elseif state == "Ground" and grounded() then
		local md = hum.MoveDirection
		local dir = md.Magnitude > 0.2 and md.Unit or flat(root.CFrame.LookVector)
		tryVault(dir)
	end
end

local function onDrop()
	if state == "Climb" then
		release(wall.n * 6)
	elseif state == "Zipline" then
		zipRelease(false)
	elseif state == "Ground" and grounded() then
		-- drop off the edge in front and hang from it
		local look = flat(root.CFrame.LookVector)
		local pos = root.Position
		if cast(pos + look * 2.5, -UP * 6) then return end
		local face = cast(pos + look * 2.5 - UP * (rootHeight() + 1.5), -look * 3.5)
		if face and isWall(face) then
			local n = flat(face.Normal)
			local floorY = pos.Y - rootHeight()
			root.CFrame = CFrame.new(Vector3.new(face.Position.X, floorY - 1.2, face.Position.Z) + n * Config.HangDistance)
				* CFrame.lookAt(ZERO, -n).Rotation
			startClimb(face)
		end
	end
end

local function onInteract()
	if state ~= "Ground" or not grounded() then return end
	local vp = standingOnViewpoint()
	if vp then
		task.spawn(synchronize, vp)
		return
	end
	local z = nearbyZipline()
	if z then
		startZipline(z)
		return
	end
	local target = findLeapTarget()
	if target then
		startDive(target)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not hum then return end
	local key = input.KeyCode
	if keyIn(Config.Keys.Sprint, key) then
		sprint = true
	elseif keyIn(Config.Keys.Interact, key) then
		onInteract()
	elseif keyIn(Config.Keys.Drop, key) then
		onDrop()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if keyIn(Config.Keys.Sprint, input.KeyCode) then
		sprint = false
	end
end)

UserInputService.JumpRequest:Connect(onJumpRequest)

remote.OnClientEvent:Connect(function(kind, who, id)
	if kind == "Synced" and who ~= player.Name then
		setPrompt(("%s synchronised %s"):format(who, tostring(id)))
	end
end)

---------------------------------------------------------------------------------------
-- character wiring
---------------------------------------------------------------------------------------
local function onCharacter(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
	animator = hum:WaitForChild("Animator")
	camera = Workspace.CurrentCamera
	state = "Ground"
	sprint = false
	wallRun, zip, dive = nil, nil, nil
	peakY = root.Position.Y
	refreshFilters()

	att = Instance.new("Attachment")
	att.Name = "ParkourAttachment"
	att.Parent = root

	mover = Instance.new("LinearVelocity")
	mover.Name = "ParkourMover"
	mover.Attachment0 = att
	mover.MaxForce = 1e6
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.VectorVelocity = ZERO
	mover.Enabled = false
	mover.Parent = root

	gyro = Instance.new("AlignOrientation")
	gyro.Name = "ParkourGyro"
	gyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
	gyro.Attachment0 = att
	gyro.MaxTorque = 1e7
	gyro.Responsiveness = 60
	gyro.Enabled = false
	gyro.Parent = root

	local function load(id, looped)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local track = animator:LoadAnimation(a)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = looped
		return track
	end
	climbTrack = load("rbxassetid://507765644", true)   -- default R15 climb
	fallTrack = load("rbxassetid://507767968", true)    -- default R15 fall
	runTrack = load("rbxassetid://913376220", true)     -- default R15 run

	hum.StateChanged:Connect(function(old, new)
		if state ~= "Ground" then return end
		if new == HS.Jumping then
			peakY = root.Position.Y
		elseif new == HS.Freefall and old ~= HS.Jumping then
			peakY = root.Position.Y
		elseif new == HS.Landed then
			handleLanding(peakY - root.Position.Y)
		end
	end)

	hum.Died:Connect(function()
		state = "Dead"
		mover.Enabled = false
		gyro.Enabled = false
		root.Anchored = false
		camera.CameraType = Enum.CameraType.Custom
		setPrompt("")
	end)
end

RunService.Heartbeat:Connect(function(dt)
	if not hum or not root or not root.Parent or hum.Health <= 0 then return end
	if state == "Ground" then
		groundUpdate(dt)
	elseif state == "Climb" then
		climbUpdate(dt)
	elseif state == "WallRun" then
		wallRunUpdate(dt)
	elseif state == "Zipline" then
		zipUpdate(dt)
	elseif state == "Dive" then
		diveUpdate(dt)
	end
end)

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

CollectionService:GetInstanceAddedSignal("Viewpoint"):Connect(updateCounter)
