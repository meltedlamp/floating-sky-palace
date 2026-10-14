--[[
	ParkourProps  -  command-bar builder (run AFTER FloatingSkyPalace.lua)

	Adds the Assassin's-Creed set dressing the parkour scripts look for:
	  - hay carts (tag "HayBale")           landing spots for the Leap of Faith
	  - viewpoint perches (tag "Viewpoint") wooden beams with a golden eagle on the tallest spires
	  - ziplines (tag "Zipline")            rope slides between spires / islands
	  - rooftop walk beams and a controls sign at the spawn

	HOW TO USE: paste this whole file into the Studio Command Bar and press Enter.
	It finds the "FloatingSkyPalace" model wherever you moved it, parents the course
	into that model so it stays attached, and re-running it replaces the previous
	"ParkourProps" model.
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local palaceModel = Workspace:FindFirstChild("FloatingSkyPalace")
assert(palaceModel, "Build the FloatingSkyPalace first (run FloatingSkyPalace.lua)")

-- the palace file places its spawn at (PX, TOP + 0.5, PZ + 95) = (28, 120.5, 87); whatever
-- the spawn is at now tells us how far the whole model has been moved.
local spawnPart = palaceModel:FindFirstChildOfClass("SpawnLocation")
local OFFSET = spawnPart and (spawnPart.Position - Vector3.new(28, 120.5, 87)) or Vector3.zero
local function P(x, y, z) return Vector3.new(x, y, z) + OFFSET end

-- palace constants (same as FloatingSkyPalace.lua)
local PX, PZ, TOP = 28, -8, 120
local Y0, Y1 = TOP, TOP + 9
local PVX, PVZ = PX - 150, PZ + 36
local EAST = { cx = 320, cy = TOP - 28, cz = 70 }
local FAR = { cx = 470, cy = TOP + 26, cz = -50 }
local WEST = { cx = -300, cy = TOP - 42, cz = 50 }

local old = palaceModel:FindFirstChild("ParkourProps") or Workspace:FindFirstChild("ParkourProps")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "ParkourProps"
root.Parent = palaceModel

local C = {
	wood = Color3.fromRGB(110, 78, 48),
	woodDark = Color3.fromRGB(78, 54, 34),
	hay = Color3.fromRGB(222, 196, 110),
	hayDark = Color3.fromRGB(196, 168, 86),
	gold = Color3.fromRGB(232, 184, 64),
	rope = Color3.fromRGB(70, 60, 50),
	iron = Color3.fromRGB(70, 70, 76),
}

local count = 0
local function part(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	count += 1
	if count % 200 == 0 then task.wait() end
	return p
end

local function group(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

-- remove trees from the palace model that would poke through a ground prop
local function clearTrees(center, radius)
	for _, d in ipairs(palaceModel:GetDescendants()) do
		if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Trees" then
			local dx, dz = d.Position.X - center.X, d.Position.Z - center.Z
			if math.sqrt(dx * dx + dz * dz) < radius and math.abs(d.Position.Y - center.Y) < 30 then
				d:Destroy()
			end
		end
	end
end

---------------------------------------------------------------------------------------
-- HAY CART (Leap of Faith target). (x, y, z) in palace coordinates, y = ground level
---------------------------------------------------------------------------------------
local function hayCart(x, y, z, yaw)
	local m = group("HayCart")
	local base = P(x, y, z)
	clearTrees(base, 9)
	local rot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	part(m, Vector3.new(9, 0.8, 7), rot * CFrame.new(0, 1.6, 0), C.wood, Enum.Material.WoodPlanks)          -- bed
	for _, sx in ipairs({ -3.2, 3.2 }) do                                                                     -- wheels
		part(m, Vector3.new(0.6, 3.2, 3.2), rot * CFrame.new(sx, 1.6, 0) * CFrame.Angles(0, math.rad(90), 0), C.woodDark, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	for _, side in ipairs({ -1, 1 }) do                                                                       -- rails
		part(m, Vector3.new(9, 1.2, 0.3), rot * CFrame.new(0, 2.6, side * 3.4), C.wood, Enum.Material.WoodPlanks)
	end
	part(m, Vector3.new(0.4, 0.4, 5), rot * CFrame.new(-6.5, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-12)), C.woodDark, Enum.Material.Wood) -- handles
	-- the hay itself: soft, tagged, slightly overlapping blocks
	local rng = Random.new(math.floor(x * 7 + z * 13))
	local hayTop = part(m, Vector3.new(8.4, 3.2, 6.4), rot * CFrame.new(0, 3.6, 0), C.hay, Enum.Material.Grass)
	hayTop.Name = "Hay"
	CollectionService:AddTag(hayTop, "HayBale")
	for i = 1, 5 do
		local s = rng:NextNumber(2.2, 3.6)
		local hp = part(m, Vector3.new(s, s * 0.8, s), rot * CFrame.new(rng:NextNumber(-2.6, 2.6), 5.0 + rng:NextNumber(0, 0.8), rng:NextNumber(-1.8, 1.8))
			* CFrame.Angles(0, rng:NextNumber(0, 3), 0), (i % 2 == 0) and C.hayDark or C.hay, Enum.Material.Grass)
		hp.Name = "Hay"
		CollectionService:AddTag(hp, "HayBale")
	end
	return m
end

---------------------------------------------------------------------------------------
-- VIEWPOINT PERCH: wooden beam sticking out from a spire at height y (beam top = y + 0.5),
-- from (x, z) outward along (dx, dz) for `length` studs, with a golden eagle at the tip.
---------------------------------------------------------------------------------------
local function viewpoint(id, title, x, y, z, dx, dz, length)
	local m = group("Viewpoint_" .. id)
	local dir = Vector3.new(dx, 0, dz).Unit
	local a = P(x, y, z)
	local b = a + dir * length
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, b)
	clearTrees(b - Vector3.new(0, 12, 0), 9)   -- nothing should break a Leap of Faith from the tip

	local beam = part(m, Vector3.new(1.2, 1.0, length), look, C.wood, Enum.Material.Wood)
	beam.Name = "Perch"
	beam:SetAttribute("Id", id)
	beam:SetAttribute("Title", title)
	CollectionService:AddTag(beam, "Viewpoint")

	-- diagonal brace under the beam
	local brace = part(m, Vector3.new(0.6, 0.6, length * 0.7), CFrame.lookAt(a - Vector3.new(0, 3.5, 0), b - Vector3.new(0, 0.6, 0)) * CFrame.new(0, 0, -length * 0.35 - 0.6), C.woodDark, Enum.Material.Wood)
	CollectionService:AddTag(brace, "NoClimb")

	-- golden eagle: body, head, two swept wings, tail
	local tip = CFrame.lookAt(b + Vector3.new(0, 1.3, 0), b + dir + Vector3.new(0, 1.3, 0))
	local function gold(size, cf, shape)
		local g = part(m, size, cf, C.gold, Enum.Material.Metal, shape)
		g.Name = "Eagle"
		g.CanCollide = false
		CollectionService:AddTag(g, "NoClimb")
		return g
	end
	gold(Vector3.new(0.9, 0.9, 1.8), tip)
	gold(Vector3.new(0.6, 0.6, 0.6), tip * CFrame.new(0, 0.5, 1.0), Enum.PartType.Ball)
	gold(Vector3.new(0.3, 0.2, 0.5), tip * CFrame.new(0, 0.45, 1.5))
	for _, side in ipairs({ -1, 1 }) do
		gold(Vector3.new(2.6, 0.15, 1.1), tip * CFrame.new(side * 1.55, 0.5, -0.1) * CFrame.Angles(0, math.rad(-side * 15), math.rad(side * 25)))
		gold(Vector3.new(1.6, 0.12, 0.8), tip * CFrame.new(side * 3.2, 1.1, -0.4) * CFrame.Angles(0, math.rad(-side * 25), math.rad(side * 40)))
	end
	gold(Vector3.new(0.8, 0.12, 1.0), tip * CFrame.new(0, 0.1, -1.3))

	-- a point light so it reads from a distance
	local light = Instance.new("PointLight")
	light.Color = C.gold
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = beam
	return m, b
end

---------------------------------------------------------------------------------------
-- ZIPLINE: start post at `a`, end post at `b` (ground positions, palace coords). Rope runs
-- from the top of one post to the top of the other.
---------------------------------------------------------------------------------------
local function zipline(name, a, b, postA, postB)
	local m = group("Zipline_" .. name)
	CollectionService:AddTag(m, "Zipline")
	local A, B = P(a.X, a.Y, a.Z), P(b.X, b.Y, b.Z)
	clearTrees(B, 8)

	local function post(pos, height, isStart)
		part(m, Vector3.new(0.8, height, 0.8), CFrame.new(pos + Vector3.new(0, height / 2, 0)), C.woodDark, Enum.Material.Wood)
		part(m, Vector3.new(1.6, 0.5, 1.6), CFrame.new(pos + Vector3.new(0, 0.25, 0)), C.iron, Enum.Material.Metal)
		local anchor = part(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, height, 0)), C.iron, Enum.Material.Metal)
		anchor.Name = isStart and "StartAnchor" or "EndAnchor"
		anchor.CanCollide = false
		CollectionService:AddTag(anchor, "NoClimb")
		return anchor
	end
	local sa = post(A, postA, true)
	local ea = post(B, postB, false)

	local ra, rb = sa.Position, ea.Position
	local len = (rb - ra).Magnitude

	-- fell any tree canopy the rope would pass through
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	for _ = 1, 30 do
		local hit = Workspace:Raycast(ra, rb - ra, params)
		if not hit then break end
		if hit.Instance.Parent and hit.Instance.Parent.Name == "Trees" then
			clearTrees(hit.Instance.Position, 8)
		else
			warn(("Zipline %s passes through %s at %s"):format(name, hit.Instance:GetFullName(), tostring(hit.Position)))
			break
		end
	end
	local rope = part(m, Vector3.new(0.3, 0.3, len), CFrame.lookAt((ra + rb) / 2, rb), C.rope, Enum.Material.Fabric)
	rope.Name = "Rope"
	rope.CanCollide = false
	CollectionService:AddTag(rope, "NoClimb")

	-- a pulley handle hanging at the start so players can see where to grab
	local handle = part(m, Vector3.new(1.6, 0.3, 0.3), CFrame.lookAt(ra, rb) * CFrame.new(0, -1.2, -2.5), C.iron, Enum.Material.Metal)
	handle.CanCollide = false
	CollectionService:AddTag(handle, "NoClimb")
	local hook = part(m, Vector3.new(0.2, 1.2, 0.2), CFrame.lookAt(ra, rb) * CFrame.new(0, -0.6, -2.5), C.iron, Enum.Material.Metal)
	hook.CanCollide = false
	CollectionService:AddTag(hook, "NoClimb")
	return m
end

---------------------------------------------------------------------------------------
-- SKY BRIDGE between two points (palace coords, deck top sits 0.35 above the given y).
-- A walkable wooden deck with rails, plus posts down to the terrace so it reads as
-- part of the castle instead of a beam hanging in empty air.
---------------------------------------------------------------------------------------
local function skyBridge(ax, ay, az, bx, by, bz)
	local m = group("SkyBridge")
	local a, b = P(ax, ay, az), P(bx, by, bz)
	local len = (b - a).Magnitude
	local look = CFrame.lookAt((a + b) / 2, b)
	part(m, Vector3.new(4.4, 0.7, len + 2), look, C.wood, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		part(m, Vector3.new(0.35, 2.4, len + 2), look * CFrame.new(side * 2.1, 1.55, 0), C.woodDark, Enum.Material.Wood)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, m }
	local n = math.max(2, math.floor(len / 8))
	for i = 0, n do
		local top = a:Lerp(b, i / n)
		local hit = Workspace:Raycast(top + Vector3.new(0, 0.2, 0), Vector3.new(0, -70, 0), params)
		if hit then
			local h = top.Y - hit.Position.Y
			if h > 5 and h < 55 then
				part(m, Vector3.new(0.9, h, 0.9), CFrame.new((top + hit.Position) / 2), C.woodDark, Enum.Material.Wood)
				part(m, Vector3.new(1.8, 0.45, 1.8), CFrame.new(hit.Position + Vector3.new(0, 0.22, 0)), C.iron, Enum.Material.Metal)
			end
		end
	end
	return m
end

---------------------------------------------------------------------------------------
-- CONTROLS SIGN
---------------------------------------------------------------------------------------
local function sign(x, y, z, yaw)
	local m = group("ControlsSign")
	local base = CFrame.new(P(x, y, z)) * CFrame.Angles(0, math.rad(yaw), 0)
	part(m, Vector3.new(0.6, 6, 0.6), base * CFrame.new(-3.2, 3, 0), C.woodDark, Enum.Material.Wood)
	part(m, Vector3.new(0.6, 6, 0.6), base * CFrame.new(3.2, 3, 0), C.woodDark, Enum.Material.Wood)
	local board = part(m, Vector3.new(8, 5, 0.4), base * CFrame.new(0, 5.5, 0), C.wood, Enum.Material.WoodPlanks)
	CollectionService:AddTag(board, "NoClimb")
	local text = table.concat({
		"FREE-RUN - hold Shift, run at walls to climb",
		"CLIMB - WASD on walls, W at a ledge to pull up",
		"LEAP - Space on a wall (W up, A/D sideways)",
		"DROP / HANG - Ctrl or C",
		"E - Synchronise viewpoints, ride ziplines,",
		"      Leap of Faith into hay from high ledges",
		"ROLL - hold Shift as you land",
	}, "\n")
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.2)
		title.Font = Enum.Font.Antique
		title.TextScaled = true
		title.TextColor3 = C.gold
		title.Text = "THE CREED OF THE SKY PALACE"
		title.Parent = gui
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromScale(0.03, 0.22)
		body.Size = UDim2.fromScale(0.94, 0.76)
		body.Font = Enum.Font.Gotham
		body.TextScaled = true
		body.TextColor3 = Color3.fromRGB(245, 238, 220)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = text
		body.Parent = gui
	end
end

---------------------------------------------------------------------------------------
-- PLACE EVERYTHING
---------------------------------------------------------------------------------------
-- hay carts: in front of the palace, behind the two big spires, beside the wings,
-- below the pavilion, and on the other islands
hayCart(PX - 24, Y1, PZ + 51, 0)
hayCart(PX + 24, Y1, PZ + 51, 0)
hayCart(PX + 52, Y1, PZ - 50, 90)
hayCart(PX - 52, Y1, PZ - 50, 90)
hayCart(PX - 98, TOP, PZ - 10, 90)
hayCart(PX + 98, TOP, PZ - 10, 90)
hayCart(PVX, TOP, PVZ - 26, 0)
hayCart(EAST.cx + 10, EAST.cy, EAST.cz + 14, 0)
hayCart(WEST.cx, WEST.cy, WEST.cz + 18, 0)
hayCart(FAR.cx - 8, FAR.cy, FAR.cz + 8, 0)

-- viewpoints: each beam starts at the spire's centre (just above its balcony ring) and sticks out
local _, domePerchTip = viewpoint("GreatDome", "The Great Dome", PX, 221.2, PZ, 0, 1, 31)
local _, eastTip = viewpoint("EastSpire", "East Spire", PX + 52, Y1 + 56.5, PZ - 38, 1, 0, 15)
local _, westTip = viewpoint("WestSpire", "West Spire", PX - 50, Y1 + 48.5, PZ - 36, -1, 0, 15)
local _, pavTip = viewpoint("PavilionSpire", "Pavilion Spire", PVX - 16, Y0 + 34.5, PVZ - 16, 0, -1, 13)
viewpoint("TempleSpire", "Ruined Temple", EAST.cx - 30, EAST.cy + 26.5, EAST.cz + 20, -1, 0, 13)
viewpoint("WestIsland", "Twin Towers", WEST.cx - 14, WEST.cy + 34.5, WEST.cz - 10, -1, 0, 13)
viewpoint("FarEast", "Far Watchtower", FAR.cx + 8, FAR.cy + 22.5, FAR.cz - 6, 1, 0, 13)

-- ziplines (start post stands on the end of a viewpoint beam; positions are in palace coords)
local function unP(v) return v - OFFSET end
local e, w, p = unP(eastTip), unP(westTip), unP(pavTip)
zipline("EastSpire_to_Temple", Vector3.new(e.X - 1.5, e.Y + 0.5, e.Z), Vector3.new(EAST.cx - 14, EAST.cy, EAST.cz), 6, 6)
zipline("WestSpire_to_Pavilion", Vector3.new(w.X + 1.5, w.Y + 0.5, w.Z), Vector3.new(PVX + 10, Y0 + 32.5, PVZ - 10), 6, 6)
zipline("Pavilion_to_WestIsland", Vector3.new(p.X, p.Y + 0.5, p.Z + 1.5), Vector3.new(WEST.cx + 12, WEST.cy + 4, WEST.cz - 4), 6, 6)

-- rooftop sky bridges from the great hall front roof into the two front spires
skyBridge(PX - 10, Y1 + 27.5, PZ + 20, PX - 10, Y1 + 28.5, PZ + 60)
skyBridge(PX + 14, Y1 + 27.5, PZ + 20, PX + 14, Y1 + 32.5, PZ + 60)

-- controls sign just in front of the spawn, facing the player
sign(PX + 9, TOP, PZ + 86, 20)

print(("ParkourProps built: %d parts, offset %s"):format(count, tostring(OFFSET)))
