--[[
	FLOATING SKY PALACE  -  procedural builder for Roblox Studio
	Recreates the "floating islands with a white domed palace" reference:
	  - several floating voxel islands with grass tops, tapered rock undersides,
	    ragged coasts, cliff ledges, moss, and small islets joined to the main land
	  - blocky trees, bushes, flowers, long waterfalls pouring off the islands
	  - white marble palace: central great dome, corner domes, tall pointed spires
	    with gold tips, colonnades, arched windows, and an arch bridge to a pavilion
	  - walkable interiors: throne room, library, dining hall, royal chambers, stairs
	  - matching sky: soft blue atmosphere, haze, volumetric clouds

	HOW TO USE
	  1. Open Roblox Studio and open any place (a Baseplate is fine).
	  2. Open the Command Bar  (View tab -> Command Bar).
	  3. Paste the ENTIRE contents of this file into the Command Bar and press Enter.
	     (Alternatively: paste it into a Script in ServerScriptService and press Play.)
	  4. Wait a few seconds. A model named "FloatingSkyPalace" appears in Workspace and the
	     Studio camera is moved to a good viewing angle.
	  Running it again deletes the previous model and rebuilds, so it's safe to tweak
	  the CONFIG values below and re-run.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

---------------------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------------------
local SEED = 1337                 -- change for a different island shape / tree layout
local V = 4                       -- voxel size (studs)
local TOP = 120                   -- height of the main island's grass surface
local YIELD_EVERY = 200           -- yield to Studio every N parts so it never times out

local rng = Random.new(SEED)

local C = {
	marble      = Color3.fromRGB(238, 238, 232),
	marbleShade = Color3.fromRGB(216, 216, 208),
	gold        = Color3.fromRGB(232, 184, 64),
	window      = Color3.fromRGB(66, 76, 96),
	grass       = Color3.fromRGB(88, 152, 62),
	grassDark   = Color3.fromRGB(68, 128, 48),
	grassLight  = Color3.fromRGB(110, 168, 72),
	moss        = Color3.fromRGB(74, 118, 58),
	dirt        = Color3.fromRGB(122, 94, 68),
	dirtDark    = Color3.fromRGB(98, 74, 52),
	stone       = Color3.fromRGB(132, 126, 116),
	stoneDark   = Color3.fromRGB(106, 100, 92),
	stonePale   = Color3.fromRGB(148, 142, 130),
	pebble      = Color3.fromRGB(118, 114, 104),
	flower      = {
		Color3.fromRGB(232, 86, 110), Color3.fromRGB(255, 214, 90),
		Color3.fromRGB(248, 248, 236), Color3.fromRGB(168, 110, 214),
	},
	trunk       = Color3.fromRGB(92, 64, 40),
	leaves      = { Color3.fromRGB(58, 125, 45), Color3.fromRGB(76, 150, 56), Color3.fromRGB(45, 105, 40) },
	water       = Color3.fromRGB(190, 225, 255),
	wood        = Color3.fromRGB(128, 90, 56),
	woodDark    = Color3.fromRGB(78, 52, 32),
	carpet      = Color3.fromRGB(148, 36, 42),
	carpetNavy  = Color3.fromRGB(42, 52, 92),
	cushion     = Color3.fromRGB(176, 48, 54),
	candle      = Color3.fromRGB(255, 236, 200),
	flame       = Color3.fromRGB(255, 168, 64),
	book        = {
		Color3.fromRGB(112, 36, 36), Color3.fromRGB(40, 62, 112),
		Color3.fromRGB(48, 92, 52), Color3.fromRGB(140, 112, 52),
		Color3.fromRGB(86, 54, 96), Color3.fromRGB(52, 52, 52),
	},
}

---------------------------------------------------------------------------------------
-- ROOT MODEL (idempotent)
---------------------------------------------------------------------------------------
local old = Workspace:FindFirstChild("FloatingSkyPalace")
if old then old:Destroy() end

local root = Instance.new("Model")
root.Name = "FloatingSkyPalace"
root.Parent = Workspace

local partCount = 0

---------------------------------------------------------------------------------------
-- PRIMITIVE HELPERS
---------------------------------------------------------------------------------------
local function newPart(parent, size, cf, color, material, shape)
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
	partCount += 1
	if partCount % YIELD_EVERY == 0 then task.wait() end
	return p
end

local function group(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

-- axis-aligned box centred at (x, y, z)
local function block(parent, x, y, z, sx, sy, sz, color, material)
	return newPart(parent, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material)
end

-- box whose BOTTOM sits at yBase
local function blockOn(parent, x, yBase, z, sx, sy, sz, color, material)
	return block(parent, x, yBase + sy / 2, z, sx, sy, sz, color, material)
end

-- vertical cylinder whose BOTTOM sits at yBase
local function cylinderOn(parent, x, yBase, z, radius, height, color, material)
	return newPart(parent, Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, yBase + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color, material, Enum.PartType.Cylinder)
end

local function ball(parent, x, y, z, radius, color, material)
	return newPart(parent, Vector3.new(radius * 2, radius * 2, radius * 2), CFrame.new(x, y, z),
		color, material, Enum.PartType.Ball)
end

---------------------------------------------------------------------------------------
-- ISLANDS
---------------------------------------------------------------------------------------
-- cfg = { name, cx, cy (grass surface Y), cz, R, depth, stretchX, stretchZ }
-- returns the model and an isInside(x, z) test for the grass top
local function buildIsland(cfg)
	local m = group(cfg.name)
	local R, depth = cfg.R, cfg.depth
	local sx, sz = cfg.stretchX or 1, cfg.stretchZ or 1
	local layers = math.floor(depth / V)

	-- lumpy outline: broad bays plus a high-frequency ragged coast
	local a1, a2, a3 = rng:NextNumber(0.06, 0.13), rng:NextNumber(0.05, 0.11), rng:NextNumber(0.03, 0.07)
	local a4, a5 = rng:NextNumber(0.018, 0.034), rng:NextNumber(0.012, 0.024)
	local p1, p2, p3 = rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283)
	local p4, p5 = rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283)
	local function outline(angle)
		return 1
			+ a1 * math.sin(2 * angle + p1)
			+ a2 * math.sin(3 * angle + p2)
			+ a3 * math.sin(5 * angle + p3)
			+ a4 * math.sin(9 * angle + p4)
			+ a5 * math.sin(14 * angle + p5)
	end

	local function isInsideRadius(lx, lz, r)
		local nx, nz = lx / sx, lz / sz
		local dist = math.sqrt(nx * nx + nz * nz)
		local ang = math.atan2(nz, nx)
		local jagged = 0.55 * V * math.sin(lx * 0.13 + p1) * math.cos(lz * 0.11 + p2)
		return dist <= r * outline(ang) + jagged
	end

	local function topColor(lx, lz)
		local n = math.noise(lx * 0.035 + p1, lz * 0.035 + p2, SEED * 0.02)
		if n > 0.30 then
			return C.grassLight, Enum.Material.Grass
		elseif n < -0.34 then
			return C.dirt, Enum.Material.Ground
		elseif n < -0.14 then
			return C.grassDark, Enum.Material.Grass
		end
		return C.grass, Enum.Material.Grass
	end

	local function stoneColor(d, lx, lz)
		local n = math.noise(lx * 0.05 + p3, d * 0.17, lz * 0.05 + p4)
		if n > 0.22 then return C.stonePale end
		if n < -0.18 or d % 3 == 0 then return C.stoneDark end
		return C.stone
	end

	local function flushRun(y, lz, runStart, runEnd, color, material)
		if runStart then
			local len = (runEnd - runStart) + V
			block(m, cfg.cx + (runStart + runEnd) / 2, y, cfg.cz + lz, len, V, V, color, material)
		end
	end

	for d = 0, layers do
		local t = d / layers
		local r = R * (1 - t) ^ 0.72
		-- a little per-layer wobble so the cliff isn't a perfect cone
		if d > 1 then r = r * (0.96 + 0.08 * math.abs(math.sin(d * 1.7 + p1))) end
		if r < V * 0.8 then break end

		local y = cfg.cy - V / 2 - d * V
		local zRange = math.ceil(r * sz / V)
		local xRange = math.ceil(r * sx / V)
		for zi = -zRange, zRange do
			local lz = zi * V
			if d == 0 then
				local runStart, runEnd, runColor, runMat
				for xi = -xRange, xRange do
					local lx = xi * V
					if isInsideRadius(lx, lz, r) then
						local col, mat = topColor(lx, lz)
						if col ~= runColor then
							flushRun(y, lz, runStart, runEnd, runColor, runMat)
							runStart, runEnd, runColor, runMat = lx, lx, col, mat
						else
							runEnd = lx
						end
					else
						flushRun(y, lz, runStart, runEnd, runColor, runMat)
						runStart, runColor = nil, nil
					end
				end
				flushRun(y, lz, runStart, runEnd, runColor, runMat)
			else
				local color, material
				if d == 1 then
					color, material = (math.noise(lz * 0.08, p2) > 0.15) and C.dirtDark or C.dirt, Enum.Material.Ground
				else
					color, material = stoneColor(d, 0, lz), Enum.Material.Slate
				end
				local xmin, xmax
				for xi = -xRange, xRange do
					local lx = xi * V
					if isInsideRadius(lx, lz, r) then
						if not xmin then xmin = lx end
						xmax = lx
					end
				end
				if xmin then
					local len = (xmax - xmin) + V
					block(m, cfg.cx + (xmin + xmax) / 2, y, cfg.cz + lz, len, V, V, color, material)
				end
			end
		end
	end

	-- ragged grassy rim around the coast
	for i = 1, math.max(10, math.floor(R / 2.6)) do
		local ang = (i / math.max(10, math.floor(R / 2.6))) * 6.283 + rng:NextNumber(-0.1, 0.1)
		local dist = R * outline(ang) * rng:NextNumber(0.90, 1.10)
		local x = cfg.cx + math.cos(ang) * dist * sx
		local z = cfg.cz + math.sin(ang) * dist * sz
		local s = V * rng:NextNumber(0.65, 1.45)
		local col = (rng:NextNumber() > 0.4) and C.grass or C.grassDark
		block(m, x, cfg.cy - V * 0.12, z, s, V * rng:NextNumber(0.45, 1.05), s, col, Enum.Material.Grass)
	end

	-- cliff ledges sticking out of the rock face
	for _ = 1, math.max(4, math.floor(R / 16)) do
		local ang = rng:NextNumber(0, 6.283)
		local dd = rng:NextInteger(1, math.max(2, math.floor(layers * 0.5)))
		local rr = R * (1 - dd / layers) ^ 0.72 * rng:NextNumber(1.02, 1.22)
		local s = V * rng:NextNumber(1.4, 3.4)
		block(m, cfg.cx + math.cos(ang) * rr * sx, cfg.cy - dd * V, cfg.cz + math.sin(ang) * rr * sz,
			s, V * rng:NextNumber(0.7, 1.3), s * rng:NextNumber(0.7, 1.2), C.stone, Enum.Material.Slate)
	end

	-- moss patches and hanging roots on the cliffs
	for _ = 1, math.max(5, math.floor(R / 10)) do
		local ang = rng:NextNumber(0, 6.283)
		local dd = rng:NextInteger(2, math.max(3, math.floor(layers * 0.7)))
		local rr = R * (1 - dd / layers) ^ 0.72 * rng:NextNumber(0.94, 1.14)
		local x = cfg.cx + math.cos(ang) * rr * sx
		local z = cfg.cz + math.sin(ang) * rr * sz
		local y = cfg.cy - dd * V
		block(m, x, y, z, V * rng:NextNumber(0.7, 1.5), V * rng:NextNumber(0.4, 0.8), V * rng:NextNumber(0.7, 1.5),
			C.moss, Enum.Material.Grass)
		if rng:NextNumber() > 0.45 then
			blockOn(m, x + rng:NextNumber(-1.2, 1.2), y - V * 0.4, z + rng:NextNumber(-1.2, 1.2),
				0.35, V * rng:NextNumber(1.1, 2.8), 0.35, C.trunk, Enum.Material.Wood)
		end
	end

	-- loose boulders clinging to the underside
	for _ = 1, math.max(3, math.floor(R / 18)) do
		local ang = rng:NextNumber(0, 6.283)
		local dd = rng:NextInteger(2, math.max(3, layers - 2))
		local rr = R * (1 - dd / layers) ^ 0.72 * rng:NextNumber(0.85, 1.22)
		local s = V * rng:NextNumber(0.9, 2.4)
		block(m, cfg.cx + math.cos(ang) * rr * sx, cfg.cy - dd * V - rng:NextNumber(0, V), cfg.cz + math.sin(ang) * rr * sz,
			s, s * rng:NextNumber(0.7, 1.2), s, C.stoneDark, Enum.Material.Slate)
	end

	-- a few stones drifting just under the island
	for _ = 1, math.max(2, math.floor(R / 28)) do
		local ang = rng:NextNumber(0, 6.283)
		local rr = R * rng:NextNumber(0.15, 0.65)
		local s = V * rng:NextNumber(0.7, 1.8)
		block(m, cfg.cx + math.cos(ang) * rr * sx, cfg.cy - rng:NextNumber(depth * 0.45, depth * 0.95),
			cfg.cz + math.sin(ang) * rr * sz, s, s, s, C.pebble, Enum.Material.Slate)
	end

	local function isInside(x, z)
		return isInsideRadius(x - cfg.cx, z - cfg.cz, R * 0.92)
	end
	return m, isInside
end

---------------------------------------------------------------------------------------
-- NATURE
---------------------------------------------------------------------------------------
local function tree(parent, x, yBase, z, scale)
	scale = scale or 1
	local trunkH = V * rng:NextInteger(2, 4) * scale
	blockOn(parent, x, yBase, z, V * 0.7 * scale, trunkH, V * 0.7 * scale, C.trunk, Enum.Material.Wood)
	local cy = yBase + trunkH
	for _ = 1, rng:NextInteger(3, 5) do
		local s = V * rng:NextNumber(1.6, 3.0) * scale
		local ox = rng:NextNumber(-V, V) * scale
		local oy = rng:NextNumber(-V * 0.5, V * 1.5) * scale
		local oz = rng:NextNumber(-V, V) * scale
		block(parent, x + ox, cy + oy + s / 2, z + oz, s, s, s,
			C.leaves[rng:NextInteger(1, #C.leaves)], Enum.Material.Grass)
	end
end

-- scatter trees across an island top, avoiding exclusion rectangles {xmin, xmax, zmin, zmax}
local function forest(parent, cfg, isInside, count, exclusions, scale)
	local placed, attempts = 0, 0
	while placed < count and attempts < count * 30 do
		attempts += 1
		local x = cfg.cx + rng:NextNumber(-cfg.R * (cfg.stretchX or 1), cfg.R * (cfg.stretchX or 1))
		local z = cfg.cz + rng:NextNumber(-cfg.R * (cfg.stretchZ or 1), cfg.R * (cfg.stretchZ or 1))
		if isInside(x, z) then
			local blocked = false
			for _, e in ipairs(exclusions or {}) do
				if x > e[1] and x < e[2] and z > e[3] and z < e[4] then
					blocked = true
					break
				end
			end
			if not blocked then
				tree(parent, x, cfg.cy, z, (scale or 1) * rng:NextNumber(0.8, 1.3))
				placed += 1
			end
		end
	end
end

local function bush(parent, x, yBase, z, scale)
	scale = scale or 1
	for _ = 1, rng:NextInteger(2, 4) do
		local s = V * rng:NextNumber(0.7, 1.35) * scale
		block(parent, x + rng:NextNumber(-V, V) * 0.45 * scale, yBase + s * 0.45,
			z + rng:NextNumber(-V, V) * 0.45 * scale, s, s * rng:NextNumber(0.55, 0.9), s,
			C.leaves[rng:NextInteger(1, #C.leaves)], Enum.Material.Grass)
	end
end

local function flower(parent, x, yBase, z)
	local stemH = rng:NextNumber(0.7, 1.4)
	blockOn(parent, x, yBase, z, 0.18, stemH, 0.18, C.grassDark, Enum.Material.Grass)
	ball(parent, x, yBase + stemH + 0.28, z, 0.28, C.flower[rng:NextInteger(1, #C.flower)], Enum.Material.SmoothPlastic)
end

-- scatter rocks, bushes, tufts and flowers on an island top
local function dressIsland(parent, cfg, isInside, exclusions)
	exclusions = exclusions or {}
	local function blocked(x, z)
		for _, e in ipairs(exclusions) do
			if x > e[1] and x < e[2] and z > e[3] and z < e[4] then return true end
		end
		return false
	end
	local function scatter(count, fn)
		local placed, attempts = 0, 0
		while placed < count and attempts < count * 24 do
			attempts += 1
			local x = cfg.cx + rng:NextNumber(-cfg.R * (cfg.stretchX or 1), cfg.R * (cfg.stretchX or 1))
			local z = cfg.cz + rng:NextNumber(-cfg.R * (cfg.stretchZ or 1), cfg.R * (cfg.stretchZ or 1))
			if isInside(x, z) and not blocked(x, z) then
				fn(x, z)
				placed += 1
			end
		end
	end
	scatter(math.max(4, math.floor(cfg.R / 8)), function(x, z)
		local s = V * rng:NextNumber(0.55, 1.5)
		block(parent, x, cfg.cy + s * 0.28, z, s, s * rng:NextNumber(0.4, 0.75), s * rng:NextNumber(0.7, 1.2),
			(rng:NextNumber() > 0.5) and C.pebble or C.stone, Enum.Material.Slate)
	end)
	scatter(math.max(3, math.floor(cfg.R / 11)), function(x, z)
		bush(parent, x, cfg.cy, z, rng:NextNumber(0.7, 1.15))
	end)
	scatter(math.max(8, math.floor(cfg.R / 4)), function(x, z)
		local s = rng:NextNumber(0.5, 1.15)
		blockOn(parent, x, cfg.cy, z, s, rng:NextNumber(0.35, 0.85), s,
			(rng:NextNumber() > 0.5) and C.grassDark or C.grassLight, Enum.Material.Grass)
	end)
	scatter(math.max(6, math.floor(cfg.R / 6)), function(x, z)
		flower(parent, x, cfg.cy, z)
	end)
end

-- grassy rock neck joining two island tops so they read as one landmass
local function landBridge(parent, x1, y1, z1, x2, y2, z2, midHalfW)
	midHalfW = midHalfW or (V * 2.4)
	local dx, dz = x2 - x1, z2 - z1
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < V then return end
	local px, pz = -dz / dist, dx / dist
	local steps = math.ceil(dist / V)
	local endHalfW = midHalfW * 1.85
	local layers = math.max(3, math.floor((dist * 0.28) / V))

	for i = 0, steps do
		local t = i / steps
		local halfW = endHalfW + (midHalfW - endHalfW) * math.sin(t * math.pi)
		local wob = math.sin(t * 7.5) * V * 0.45
		local x = x1 + dx * t + px * wob
		local z = z1 + dz * t + pz * wob
		local yTop = y1 + (y2 - y1) * t
		for d = 0, layers do
			local fade = (1 - d / layers) ^ 0.68
			local hw = halfW * fade
			if hw < V * 0.35 then break end
			local y = yTop - V / 2 - d * V
			local color, material
			if d == 0 then
				color, material = C.grass, Enum.Material.Grass
			elseif d == 1 then
				color, material = C.dirt, Enum.Material.Ground
			else
				color, material = ((d % 2 == 0) and C.stoneDark or C.stone), Enum.Material.Slate
			end
			local len = hw * 2
			block(parent, x, y, z, math.abs(px) * len + V * 0.85, V, math.abs(pz) * len + V * 0.85, color, material)
		end
	end
end

local function rimToward(cfg, tx, tz, inset)
	inset = inset or 0.88
	local dx, dz = tx - cfg.cx, tz - cfg.cz
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1 then return cfg.cx, cfg.cy, cfg.cz end
	return cfg.cx + (dx / len) * cfg.R * (cfg.stretchX or 1) * inset,
		cfg.cy,
		cfg.cz + (dz / len) * cfg.R * (cfg.stretchZ or 1) * inset
end

local function waterfall(parent, x, yTop, z, length, width)
	local wf = newPart(parent, Vector3.new(width, length, 1.6), CFrame.new(x, yTop - length / 2, z),
		C.water, Enum.Material.Glass)
	wf.Transparency = 0.3
	wf.CanCollide = false
	wf.CastShadow = false

	-- streaks of falling water
	local stream = Instance.new("ParticleEmitter")
	stream.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	stream.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	stream.Size = NumberSequence.new(1.2, 2.5)
	stream.Lifetime = NumberRange.new(1.8, 2.4)
	stream.Rate = 40
	stream.Speed = NumberRange.new(30, 40)
	stream.Acceleration = Vector3.new(0, -40, 0)
	stream.EmissionDirection = Enum.NormalId.Bottom
	stream.LightEmission = 0.3
	stream.Parent = wf

	-- mist cloud at the bottom
	local mistPart = newPart(parent, Vector3.new(width * 2, 2, width * 2), CFrame.new(x, yTop - length, z), C.water)
	mistPart.Transparency = 1
	mistPart.CanCollide = false
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(6, 14)
	mist.Lifetime = NumberRange.new(2, 3.5)
	mist.Rate = 12
	mist.Speed = NumberRange.new(2, 5)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.LightEmission = 0.2
	mist.Parent = mistPart
end

---------------------------------------------------------------------------------------
-- ARCHITECTURE
---------------------------------------------------------------------------------------
-- arched window: cf = centre of the window's bottom edge on the wall surface, LookVector = outward
local function archWindow(parent, cf, w, h, depth)
	local rectH = h - w / 2
	newPart(parent, Vector3.new(w, rectH, depth), cf * CFrame.new(0, rectH / 2, 0), C.window, Enum.Material.Glass)
	newPart(parent, Vector3.new(depth, w, w), cf * CFrame.new(0, rectH, 0) * CFrame.Angles(0, math.rad(90), 0),
		C.window, Enum.Material.Glass, Enum.PartType.Cylinder)
end

-- unique sorted numbers (epsilon merge)
local function uniq(t)
	table.sort(t)
	local r = { t[1] }
	for i = 2, #t do
		if t[i] - r[#r] > 0.04 then r[#r + 1] = t[i] end
	end
	return r
end

-- horizontal slab with an optional rectangular hole { dx, dz, hx, hz } from centre
local function slabWithHole(parent, x, yBase, z, sx, sy, sz, hole, color, material)
	if not hole then
		return blockOn(parent, x, yBase, z, sx, sy, sz, color, material)
	end
	local dx, dz, hx, hz = hole[1], hole[2], hole[3], hole[4]
	local x0, x1, z0, z1 = -sx / 2, sx / 2, -sz / 2, sz / 2
	local hx0 = math.max(x0, dx - hx / 2)
	local hx1 = math.min(x1, dx + hx / 2)
	local hz0 = math.max(z0, dz - hz / 2)
	local hz1 = math.min(z1, dz + hz / 2)
	if hx1 - hx0 < 0.2 or hz1 - hz0 < 0.2 then
		return blockOn(parent, x, yBase, z, sx, sy, sz, color, material)
	end
	if hx0 - x0 > 0.15 then
		blockOn(parent, x + (x0 + hx0) / 2, yBase, z, hx0 - x0, sy, sz, color, material)
	end
	if x1 - hx1 > 0.15 then
		blockOn(parent, x + (hx1 + x1) / 2, yBase, z, x1 - hx1, sy, sz, color, material)
	end
	local midW, midX = hx1 - hx0, x + (hx0 + hx1) / 2
	if hz0 - z0 > 0.15 then
		blockOn(parent, midX, yBase, z + (z0 + hz0) / 2, midW, sy, hz0 - z0, color, material)
	end
	if z1 - hz1 > 0.15 then
		blockOn(parent, midX, yBase, z + (hz1 + z1) / 2, midW, sy, z1 - hz1, color, material)
	end
end

-- wall with rectangular openings. alongX=true means the wall runs along X (thin in Z).
-- openings: { along, y, w, h, glass? }
local function wallWithOpenings(parent, cx, yBase, cz, length, height, thickness, alongX, openings, color, material)
	color = color or C.marble
	material = material or Enum.Material.SmoothPlastic
	openings = openings or {}
	local xs, ys = { -length / 2, length / 2 }, { 0, height }
	for _, o in ipairs(openings) do
		xs[#xs + 1] = o.along - o.w / 2
		xs[#xs + 1] = o.along + o.w / 2
		ys[#ys + 1] = o.y
		ys[#ys + 1] = o.y + o.h
	end
	xs, ys = uniq(xs), uniq(ys)

	local function hit(mx, my)
		for _, o in ipairs(openings) do
			if mx > o.along - o.w / 2 + 0.03 and mx < o.along + o.w / 2 - 0.03
				and my > o.y + 0.03 and my < o.y + o.h - 0.03 then
				return o
			end
		end
		return nil
	end

	for i = 1, #xs - 1 do
		local a0, a1 = xs[i], xs[i + 1]
		local mw, mx = a1 - a0, (a0 + a1) / 2
		if mw > 0.08 then
			for j = 1, #ys - 1 do
				local b0, b1 = ys[j], ys[j + 1]
				local mh, my = b1 - b0, (b0 + b1) / 2
				if mh > 0.08 then
					local o = hit(mx, my)
					if not o then
						if alongX then
							blockOn(parent, cx + mx, yBase + b0, cz, mw, mh, thickness, color, material)
						else
							blockOn(parent, cx, yBase + b0, cz + mx, thickness, mh, mw, color, material)
						end
					elseif o.glass then
						local g
						if alongX then
							g = blockOn(parent, cx + mx, yBase + b0, cz, mw, mh, 0.4, C.window, Enum.Material.Glass)
						else
							g = blockOn(parent, cx, yBase + b0, cz + mx, 0.4, mh, mw, C.window, Enum.Material.Glass)
						end
						g.Transparency = 0.38
					end
				end
			end
		end
	end
end

local function doorSpec(d)
	if d == true then return { along = 0, w = 12, h = 14 } end
	if type(d) == "table" then
		return { along = d.along or 0, w = d.w or 12, h = d.h or 14 }
	end
	return nil
end

-- hollow hall: floor, ceiling, four walls with door/window openings, exterior moulding
-- opts = { color, floorColor, floorMaterial, doors = { n,s,e,w }, floorHole, ceilingHole }
local function hall(parent, x, yBase, z, sx, sy, sz, spacing, opts)
	opts = opts or {}
	if typeof(opts) == "Color3" then opts = { color = opts } end
	local color = opts.color or C.marble
	local floorColor = opts.floorColor or color
	local floorMat = opts.floorMaterial or Enum.Material.Marble
	local W = 2.4
	local floorH, ceilH = 1.0, 1.4
	local doors = opts.doors or {}

	slabWithHole(parent, x, yBase, z, sx, floorH, sz, opts.floorHole, floorColor, floorMat)
	slabWithHole(parent, x, yBase + sy - ceilH, z, sx, ceilH, sz, opts.ceilingHole, color)
	blockOn(parent, x, yBase + sy, z, sx + 3, 1.5, sz + 3, C.marbleShade) -- cornice
	blockOn(parent, x, yBase, z, sx + 2, 1.5, sz + 2, C.marbleShade)      -- base moulding

	local winW, winH = 3.2, math.min(sy * 0.5, 10)
	local winY = math.max(floorH + 1.5, sy * 0.22)

	local function faceOpenings(axisLen, door)
		local openings = {}
		local spec = doorSpec(door)
		if spec then
			openings[#openings + 1] = { along = spec.along, y = 0, w = spec.w, h = math.min(spec.h, sy - 2.5) }
		end
		local n = math.max(0, math.floor(axisLen / spacing))
		if n < 1 then return openings end
		local start = -(n - 1) * spacing / 2
		for i = 0, n - 1 do
			local along = start + i * spacing
			if not spec or math.abs(along - spec.along) > spec.w / 2 + winW / 2 + 1.2 then
				openings[#openings + 1] = { along = along, y = winY, w = winW, h = winH, glass = true }
			end
		end
		return openings
	end

	-- +Z / -Z walls run along X at full width; +X / -X walls sit between them
	wallWithOpenings(parent, x, yBase, z + sz / 2 - W / 2, sx, sy, W, true, faceOpenings(sx - 8, doors.n), color)
	wallWithOpenings(parent, x, yBase, z - sz / 2 + W / 2, sx, sy, W, true, faceOpenings(sx - 8, doors.s), color)
	wallWithOpenings(parent, x + sx / 2 - W / 2, yBase, z, sz - W * 2, sy, W, false, faceOpenings(sz - 8, doors.e), color)
	wallWithOpenings(parent, x - sx / 2 + W / 2, yBase, z, sz - W * 2, sy, W, false, faceOpenings(sz - 8, doors.w), color)
end

-- row of columns with an entablature, from (x1,z1) to (x2,z2)
local function colonnade(parent, x1, z1, x2, z2, yBase, height, spacing, depth)
	depth = depth or 4
	local a, b = Vector3.new(x1, yBase, z1), Vector3.new(x2, yBase, z2)
	local span = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.max(2, math.floor(span / spacing) + 1)
	for i = 0, n - 1 do
		local p = a + dir * (span * i / (n - 1))
		cylinderOn(parent, p.X, yBase, p.Z, 1.0, height, C.marble)
		cylinderOn(parent, p.X, yBase + height - 1.2, p.Z, 1.5, 1.2, C.marbleShade)  -- capital
		cylinderOn(parent, p.X, yBase, p.Z, 1.4, 0.8, C.marbleShade)                 -- base
	end
	local mid = (a + b) / 2
	newPart(parent, Vector3.new(depth, 2.5, span + 3),
		CFrame.lookAt(mid, b) * CFrame.new(0, height + 1.25, 0), C.marble)
end

-- drum + dome + optional lantern. returns top Y
local function domeTower(parent, x, yBase, z, r, drumH, withLantern, withColumns)
	cylinderOn(parent, x, yBase, z, r, drumH, C.marble)
	cylinderOn(parent, x, yBase + drumH - 1.5, z, r + 1.2, 1.5, C.marbleShade)        -- cornice ring
	if withColumns then
		local n = math.max(8, math.floor(r * 0.75))
		for i = 0, n - 1 do
			local ang = (i / n) * 6.283
			cylinderOn(parent, x + math.cos(ang) * (r + 1.6), yBase, z + math.sin(ang) * (r + 1.6), 0.9, drumH - 1.5, C.marble)
		end
		-- small arched windows between columns
		for i = 0, n - 1 do
			local ang = (i + 0.5) / n * 6.283
			local cf = CFrame.new(x + math.cos(ang) * r, yBase + drumH * 0.25, z + math.sin(ang) * r)
				* CFrame.Angles(0, -ang - math.rad(90), 0)
			archWindow(parent, cf, 2.2, drumH * 0.5, 0.6)
		end
	end
	ball(parent, x, yBase + drumH, z, r, C.marble)   -- lower half hidden inside drum
	-- ribs on the dome
	local ribs = math.max(8, math.floor(r))
	for i = 0, ribs - 1 do
		local ang = (i / ribs) * 6.283
		local rib = newPart(parent, Vector3.new(0.5, r * 1.0, 0.5),
			CFrame.new(x, yBase + drumH, z) * CFrame.Angles(0, -ang, 0)
				* CFrame.new(r * 0.72, r * 0.62, 0) * CFrame.Angles(0, 0, math.rad(42)),
			C.marbleShade)
		rib.CanCollide = false
	end
	local top = yBase + drumH + r
	if withLantern then
		local lr = r * 0.28
		cylinderOn(parent, x, top - 1, z, lr, lr * 1.3, C.marble)
		ball(parent, x, top - 1 + lr * 1.3, z, lr, C.marble)
		local finialBase = top - 1 + lr * 2.3
		cylinderOn(parent, x, finialBase, z, 0.5, lr * 1.2, C.gold, Enum.Material.Metal)
		ball(parent, x, finialBase + lr * 1.2 + 1, z, 1.2, C.gold, Enum.Material.Metal)
		top = finialBase + lr * 1.2 + 2.2
	else
		cylinderOn(parent, x, top - 0.5, z, 0.4, 2.5, C.gold, Enum.Material.Metal)
		ball(parent, x, top + 2.6, z, 0.9, C.gold, Enum.Material.Metal)
	end
	return top
end

-- tall thin tower with a stepped pointed roof and gold tip
local function spire(parent, x, yBase, z, r, towerH, coneH)
	cylinderOn(parent, x, yBase, z, r, towerH, C.marble)
	cylinderOn(parent, x, yBase, z, r + 1, 2, C.marbleShade)                 -- base
	cylinderOn(parent, x, yBase + towerH - 2, z, r + 1.3, 2, C.marbleShade)  -- balcony ring
	-- little windows up the tower
	local n = math.floor(towerH / 10)
	for i = 1, n do
		for k = 0, 3 do
			local ang = k * math.pi / 2
			local cf = CFrame.new(x + math.cos(ang) * r, yBase + i * 10 - 6, z + math.sin(ang) * r)
				* CFrame.Angles(0, -ang - math.rad(90), 0)
			archWindow(parent, cf, 1.4, 3.5, 0.5)
		end
	end
	-- stepped cone
	local steps = 9
	for i = 0, steps - 1 do
		local f = 1 - i / steps
		cylinderOn(parent, x, yBase + towerH + i * (coneH / steps), z, (r + 1.3) * f + 0.2, coneH / steps + 0.05, C.marbleShade)
	end
	local tipBase = yBase + towerH + coneH
	cylinderOn(parent, x, tipBase, z, 0.35, 4, C.gold, Enum.Material.Metal)
	ball(parent, x, tipBase + 4.8, z, 0.9, C.gold, Enum.Material.Metal)
end

-- arched bridge between two points at deck height yDeck
local function archBridge(parent, ax, az, bx, bz, yDeck, width, archDrop, pierBottomY)
	local a, b = Vector3.new(ax, yDeck, az), Vector3.new(bx, yDeck, bz)
	local span = (b - a).Magnitude
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, b)

	newPart(parent, Vector3.new(width, 2, span + 4), look, C.marble)                           -- deck
	for side = -1, 1, 2 do                                                                      -- parapets
		newPart(parent, Vector3.new(0.8, 2.6, span + 4), look * CFrame.new(side * (width / 2 - 0.4), 2.3, 0), C.marbleShade)
		local posts = math.floor(span / 6)
		for i = 0, posts do
			newPart(parent, Vector3.new(1.4, 3.6, 1.4),
				look * CFrame.new(side * (width / 2 - 0.4), 2.8, -span / 2 + i * (span / posts)), C.marble)
		end
	end

	-- arch under the deck (half-ellipse)
	local N = 16
	local rx, ry = span / 2 - 1, archDrop
	local pts = {}
	for i = 0, N do
		local th = math.pi * i / N
		local along = -math.cos(th) * rx
		local vert = -1 - (1 - math.sin(th)) * ry
		pts[#pts + 1] = mid + dir * along + Vector3.new(0, vert, 0)
	end
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local len = (q - p).Magnitude
		newPart(parent, Vector3.new(width - 1, 2.6, len + 0.8), CFrame.lookAt((p + q) / 2, q), C.marble)
	end
	-- spandrel fill between arch ends and deck + piers down to the ground
	for _, e in ipairs({ a, b }) do
		local towards = (mid - e).Unit
		local footY = yDeck - 1 - archDrop
		newPart(parent, Vector3.new(width, archDrop + 1, 6), CFrame.lookAt(e + towards * 3, e + towards * 10) * CFrame.new(0, -(archDrop + 1) / 2, 0), C.marble)
		if pierBottomY and pierBottomY < footY then
			newPart(parent, Vector3.new(width + 1, footY - pierBottomY, 7),
				CFrame.lookAt(e + towards * 3, e + towards * 10) * CFrame.new(0, -(archDrop + 1) - (footY - pierBottomY) / 2, 0),
				C.marbleShade)
		end
	end
end

---------------------------------------------------------------------------------------
-- INTERIOR FURNITURE
---------------------------------------------------------------------------------------
local function addLight(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range or 36
	l.Brightness = brightness or 1.8
	l.Color = color or Color3.fromRGB(255, 214, 158)
	l.Shadows = false
	l.Parent = part
	return l
end

local function chandelier(parent, x, yCeil, z, range)
	local hang = 6.2
	local chain = cylinderOn(parent, x, yCeil - hang, z, 0.12, hang, C.gold, Enum.Material.Metal)
	chain.CanCollide = false
	local bowl = block(parent, x, yCeil - hang - 0.35, z, 5.6, 0.5, 5.6, C.gold, Enum.Material.Metal)
	bowl.CanCollide = false
	for i = 0, 3 do
		local ang = i * math.pi / 2
		local cx = x + math.cos(ang) * 1.9
		local cz = z + math.sin(ang) * 1.9
		local candle = cylinderOn(parent, cx, yCeil - hang - 0.1, cz, 0.18, 1.1, C.candle)
		candle.CanCollide = false
		local flame = ball(parent, cx, yCeil - hang + 1.15, cz, 0.22, C.flame, Enum.Material.Neon)
		flame.CanCollide = false
		flame.CastShadow = false
		if i == 0 then addLight(flame, range or 34, 1.55) end
	end
end

local function sconce(parent, x, y, z, yaw)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local arm = newPart(parent, Vector3.new(0.35, 0.35, 1.4), cf * CFrame.new(0, 0, 0.55), C.gold, Enum.Material.Metal)
	arm.CanCollide = false
	local pos = (cf * CFrame.new(0, 0.55, 1.15)).Position
	local flame = ball(parent, pos.X, pos.Y, pos.Z, 0.22, C.flame, Enum.Material.Neon)
	flame.CanCollide = false
	flame.CastShadow = false
	addLight(flame, 16, 0.85)
end

local function rug(parent, x, y, z, sx, sz, color)
	local p = block(parent, x, y, z, sx, 0.18, sz, color or C.carpet, Enum.Material.Fabric)
	p.CanCollide = false
	return p
end

local function banner(parent, x, yTop, z, yaw)
	local cf = CFrame.new(x, yTop, z) * CFrame.Angles(0, yaw, 0)
	local pole = newPart(parent, Vector3.new(0.35, 9, 0.35), cf * CFrame.new(0, -4.5, 0), C.gold, Enum.Material.Metal)
	pole.CanCollide = false
	local cloth = newPart(parent, Vector3.new(4.2, 7.5, 0.22), cf * CFrame.new(0, -5, 0.18), C.carpet, Enum.Material.Fabric)
	cloth.CanCollide = false
	local stripe = newPart(parent, Vector3.new(1.0, 7.5, 0.24), cf * CFrame.new(0, -5, 0.22), C.gold, Enum.Material.Metal)
	stripe.CanCollide = false
end

local function throne(parent, x, yBase, z, yaw)
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	newPart(parent, Vector3.new(6.2, 1.3, 5.2), cf * CFrame.new(0, 1.85, 0.2), C.woodDark, Enum.Material.Wood)
	newPart(parent, Vector3.new(5.4, 0.5, 4.4), cf * CFrame.new(0, 2.7, 0.3), C.cushion, Enum.Material.Fabric)
	newPart(parent, Vector3.new(6.6, 8.2, 1.2), cf * CFrame.new(0, 5.7, -2.2), C.woodDark, Enum.Material.Wood)
	newPart(parent, Vector3.new(5.2, 1.3, 1.4), cf * CFrame.new(0, 10.3, -2.2), C.gold, Enum.Material.Metal)
	newPart(parent, Vector3.new(1.15, 2.5, 5), cf * CFrame.new(2.85, 3.4, 0.1), C.gold, Enum.Material.Metal)
	newPart(parent, Vector3.new(1.15, 2.5, 5), cf * CFrame.new(-2.85, 3.4, 0.1), C.gold, Enum.Material.Metal)
end

local function chair(parent, x, yBase, z, yaw)
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	newPart(parent, Vector3.new(2.1, 1.55, 2.1), cf * CFrame.new(0, 0.85, 0), C.woodDark, Enum.Material.Wood)
	newPart(parent, Vector3.new(2.1, 2.6, 0.4), cf * CFrame.new(0, 2.5, -0.85), C.woodDark, Enum.Material.Wood)
end

local function longTable(parent, x, yBase, z, length, width)
	blockOn(parent, x, yBase + 3.15, z, length, 0.55, width, C.wood, Enum.Material.WoodPlanks)
	for _, ox in ipairs({ -length / 2 + 1.1, length / 2 - 1.1 }) do
		for _, oz in ipairs({ -width / 2 + 0.7, width / 2 - 0.7 }) do
			blockOn(parent, x + ox, yBase, z + oz, 0.7, 3.15, 0.7, C.woodDark, Enum.Material.Wood)
		end
	end
	blockOn(parent, x, yBase, z + width / 2 + 1.35, length * 0.88, 1.55, 1.35, C.woodDark, Enum.Material.Wood)
	blockOn(parent, x, yBase, z - width / 2 - 1.35, length * 0.88, 1.55, 1.35, C.woodDark, Enum.Material.Wood)
end

local function bookshelf(parent, x, yBase, z, yaw, width, height)
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	newPart(parent, Vector3.new(width, height, 1.5), cf * CFrame.new(0, height / 2, 0), C.woodDark, Enum.Material.Wood)
	local rows = 4
	local books = math.max(4, math.floor(width / 0.72))
	local start = -(books - 1) * 0.52 / 2
	for r = 1, rows do
		local ry = 0.7 + (r - 1) * ((height - 1.6) / (rows - 1))
		for b = 0, books - 1 do
			if rng:NextNumber() > 0.08 then
				local bh = rng:NextNumber(1.3, 2.2)
				local book = newPart(parent, Vector3.new(0.38, bh, 1.05),
					cf * CFrame.new(start + b * 0.52, ry + bh / 2, 0.12),
					C.book[rng:NextInteger(1, #C.book)])
				book.CanCollide = false
			end
		end
	end
end

local function bed(parent, x, yBase, z, yaw)
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	newPart(parent, Vector3.new(6.6, 1.15, 10.2), cf * CFrame.new(0, 0.75, 0), C.woodDark, Enum.Material.Wood)
	newPart(parent, Vector3.new(6.1, 1.0, 9.3), cf * CFrame.new(0, 1.7, 0.15), Color3.fromRGB(232, 224, 214), Enum.Material.Fabric)
	newPart(parent, Vector3.new(6.1, 0.45, 6.2), cf * CFrame.new(0, 2.2, 1.3), C.carpet, Enum.Material.Fabric)
	newPart(parent, Vector3.new(5.4, 0.75, 1.8), cf * CFrame.new(0, 2.25, -3.6), C.marble, Enum.Material.Fabric)
	newPart(parent, Vector3.new(6.6, 4.4, 0.7), cf * CFrame.new(0, 2.9, -4.85), C.woodDark, Enum.Material.Wood)
end

local function fireplace(parent, x, yBase, z, yaw)
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	newPart(parent, Vector3.new(10, 12, 2.8), cf * CFrame.new(0, 6, 0), C.stoneDark, Enum.Material.Slate)
	newPart(parent, Vector3.new(11, 1.4, 3.4), cf * CFrame.new(0, 12.4, 0), C.marbleShade)
	local fire = newPart(parent, Vector3.new(4.2, 3.2, 1.5), cf * CFrame.new(0, 2.4, 0.5), C.flame, Enum.Material.Neon)
	fire.CanCollide = false
	fire.CastShadow = false
	addLight(fire, 24, 1.7, Color3.fromRGB(255, 150, 70))
	local em = Instance.new("ParticleEmitter")
	em.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 30, 10)),
	})
	em.Size = NumberSequence.new(0.8, 0.1)
	em.Lifetime = NumberRange.new(0.5, 1.1)
	em.Rate = 18
	em.Speed = NumberRange.new(2, 5)
	em.SpreadAngle = Vector2.new(18, 18)
	em.LightEmission = 0.6
	em.Parent = fire
end

local function openDoors(parent, x, yBase, z, yaw, w, h)
	local cf = CFrame.new(x, yBase + h / 2, z) * CFrame.Angles(0, yaw, 0)
	local leafW, leafH, leafD = w / 2 - 0.15, h - 0.6, 0.4
	local left = newPart(parent, Vector3.new(leafW, leafH, leafD),
		cf * CFrame.new(-w / 2, 0, 0) * CFrame.Angles(0, math.rad(-72), 0) * CFrame.new(leafW / 2, 0, 0),
		C.woodDark, Enum.Material.Wood)
	left.CanCollide = false
	local right = newPart(parent, Vector3.new(leafW, leafH, leafD),
		cf * CFrame.new(w / 2, 0, 0) * CFrame.Angles(0, math.rad(72), 0) * CFrame.new(-leafW / 2, 0, 0),
		C.woodDark, Enum.Material.Wood)
	right.CanCollide = false
end

-- yaw 0: stairs climb toward +Z. returns { run }
local function stairs(parent, x, yBase, z, height, width, yaw, stepH, stepD)
	stepH = stepH or 1.2
	stepD = stepD or 1.55
	local n = math.max(2, math.floor(height / stepH + 0.5))
	stepH = height / n
	local cf = CFrame.new(x, yBase, z) * CFrame.Angles(0, yaw, 0)
	for i = 0, n - 1 do
		newPart(parent, Vector3.new(width, stepH, stepD + 0.06),
			cf * CFrame.new(0, i * stepH + stepH / 2, i * stepD + stepD / 2), C.marbleShade)
	end
	return n * stepD
end

---------------------------------------------------------------------------------------
-- SCENE: MAIN ISLAND + PALACE
---------------------------------------------------------------------------------------
local mainCfg = { name = "MainIsland", cx = 0, cy = TOP, cz = 0, R = 158, depth = 132, stretchX = 1.22, stretchZ = 0.98 }
local mainIsland, mainInside = buildIsland(mainCfg)

local palace = group("Palace")
local PX, PZ = 28, -8               -- palace centre (castle sits slightly right of the island centre)
local Y0 = TOP                      -- ground

-- terraces
blockOn(palace, PX, Y0, PZ, 170, 5, 130, C.marbleShade)
blockOn(palace, PX, Y0 + 5, PZ, 150, 4, 112, C.marble)
local Y1 = Y0 + 9                   -- palace floor level

-- front steps (toward +Z)
for i = 0, 3 do
	blockOn(palace, PX, Y0 + i * 2.25, PZ + 56 + (3 - i) * 3 + 6, 40, 2.25, 3, C.marble)
end

-- great hall + upper hall + central dome (hollow, with stair well)
local stairHole = { -20, 3.5, 12, 18 } -- { dx, dz, hx, hz } from palace centre
hall(palace, PX, Y1, PZ, 92, 26, 64, 8, {
	doors = {
		n = { w = 16, h = 16 },
		s = { w = 10, h = 13 },
		e = { along = 4, w = 11, h = 13 },
		w = { along = 4, w = 11, h = 13 },
	},
	ceilingHole = stairHole,
})
hall(palace, PX, Y1 + 26, PZ, 58, 18, 44, 8, {
	floorColor = C.wood,
	floorMaterial = Enum.Material.WoodPlanks,
	floorHole = stairHole,
})
domeTower(palace, PX, Y1 + 44, PZ, 24, 16, true, true)

-- corner domes on the great hall roof
for _, dx in ipairs({ -38, 38 }) do
	for _, dz in ipairs({ -24, 24 }) do
		domeTower(palace, PX + dx, Y1 + 26, PZ + dz, 7, 7, false, false)
	end
end

-- front portico colonnade
colonnade(palace, PX - 42, PZ + 42, PX + 42, PZ + 42, Y1, 13, 7, 5)
blockOn(palace, PX, Y1, PZ + 40, 90, 1, 12, C.marbleShade)   -- portico floor

-- east & west wings (library west, dining east)
hall(palace, PX - 62, Y1, PZ + 4, 36, 18, 48, 8, {
	floorColor = C.wood,
	floorMaterial = Enum.Material.WoodPlanks,
	doors = { e = true },
})
hall(palace, PX + 62, Y1, PZ + 4, 36, 18, 48, 8, {
	floorColor = C.wood,
	floorMaterial = Enum.Material.WoodPlanks,
	doors = { w = true },
})
domeTower(palace, PX - 62, Y1 + 18, PZ + 4, 10, 8, true, false)
domeTower(palace, PX + 62, Y1 + 18, PZ + 4, 10, 8, true, false)

-- side arcades along the wings
colonnade(palace, PX - 82, PZ - 22, PX - 82, PZ + 30, Y1, 10, 6.5, 4)
colonnade(palace, PX + 82, PZ - 22, PX + 82, PZ + 30, Y1, 10, 6.5, 4)

-- spires (tall, thin, pointed, gold-tipped) around the palace
spire(palace, PX - 50, Y1, PZ - 36, 4.5, 48, 26)
spire(palace, PX + 52, Y1, PZ - 38, 4.5, 56, 28)
spire(palace, PX - 86, Y1, PZ + 38, 3.8, 36, 22)
spire(palace, PX + 88, Y1, PZ + 40, 3.8, 40, 24)
spire(palace, PX - 10, Y1, PZ + 60, 3.2, 30, 18)
spire(palace, PX + 14, Y1, PZ + 60, 3.2, 34, 20)
spire(palace, PX + 4, Y1 + 26, PZ - 36, 3.4, 30, 20)

-- rear terrace garden hedges
for i = -3, 3 do
	blockOn(palace, PX + i * 14, Y0 + 9, PZ - 52, 8, 2.5, 3, C.leaves[3], Enum.Material.Grass)
end

---------------------------------------------------------------------------------------
-- PALACE INTERIOR
---------------------------------------------------------------------------------------
local interior = group("Interior", palace)
local FY = Y1 + 1 -- walkable ground floor
local UY = Y1 + 27 -- walkable upper floor

-- grand double staircase (west side of the throne room) + landing
do
	local st = group("Stairs", interior)
	stairs(st, PX - 30, FY, PZ + 16, 13, 8, math.pi)
	block(st, PX - 25, FY + 13 - 0.5, PZ - 4, 18, 1.0, 10, C.marbleShade)
	stairs(st, PX - 20, FY + 13, PZ - 5, 13, 8, 0)
end

-- THRONE ROOM (great hall)
do
	local room = group("ThroneRoom", interior)
	rug(room, PX, FY + 0.12, PZ + 2, 14, 42, C.carpet)
	blockOn(room, PX, FY, PZ - 22, 22, 1.5, 14, C.marbleShade) -- dais
	throne(room, PX, FY + 1.5, PZ - 22, 0)
	banner(room, PX - 22, FY + 20, PZ - 28, 0)
	banner(room, PX + 22, FY + 20, PZ - 28, 0)
	banner(room, PX - 40, FY + 18, PZ + 8, math.rad(90))
	banner(room, PX + 40, FY + 18, PZ + 8, math.rad(-90))
	for _, dz in ipairs({ -14, 4, 18 }) do
		cylinderOn(room, PX + 20, FY, PZ + dz, 1.25, 22, C.marble)
		cylinderOn(room, PX + 20, FY + 21, PZ + dz, 1.7, 1.2, C.marbleShade)
		if dz ~= 4 then
			cylinderOn(room, PX - 18, FY, PZ + dz, 1.25, 22, C.marble)
			cylinderOn(room, PX - 18, FY + 21, PZ + dz, 1.7, 1.2, C.marbleShade)
		end
	end
	chandelier(room, PX, Y1 + 24.5, PZ + 6, 40)
	chandelier(room, PX, Y1 + 24.5, PZ - 10, 32)
	sconce(room, PX - 43, FY + 10, PZ + 18, math.rad(90))
	sconce(room, PX + 43, FY + 10, PZ + 18, math.rad(-90))
	sconce(room, PX - 43, FY + 10, PZ - 10, math.rad(90))
	sconce(room, PX + 43, FY + 10, PZ - 10, math.rad(-90))
	openDoors(room, PX, FY, PZ + 31.2, 0, 16, 15)
end

-- WEST WING: library
do
	local room = group("Library", interior)
	local cx, cz = PX - 62, PZ + 4
	rug(room, cx, FY + 0.12, cz, 16, 28, C.carpetNavy)
	for i = -2, 2 do
		bookshelf(room, cx - 14.5, FY, cz + i * 7.5, math.rad(-90), 6.8, 12)
	end
	for i = -1, 1 do
		if i ~= 0 then
			bookshelf(room, cx + 14.5, FY, cz + i * 12, math.rad(90), 6.8, 12)
		end
	end
	longTable(room, cx + 1, FY, cz, 14, 5)
	chair(room, cx - 6, FY, cz + 8, math.rad(180))
	chair(room, cx + 6, FY, cz + 8, math.rad(180))
	chandelier(room, cx, Y1 + 16.5, cz, 28)
	sconce(room, cx, FY + 8, cz - 20, math.rad(180))
	sconce(room, cx, FY + 8, cz + 20, 0)
end

-- EAST WING: dining hall
do
	local room = group("DiningHall", interior)
	local cx, cz = PX + 62, PZ + 4
	rug(room, cx, FY + 0.12, cz, 14, 30, C.carpet)
	longTable(room, cx, FY, cz - 6, 20, 6)
	longTable(room, cx, FY, cz + 10, 16, 5.5)
	fireplace(room, cx + 14.6, FY, cz, math.rad(-90))
	chandelier(room, cx, Y1 + 16.5, cz, 28)
	sconce(room, cx - 14, FY + 8, cz - 16, math.rad(90))
	sconce(room, cx - 14, FY + 8, cz + 16, math.rad(90))
end

-- UPPER FLOOR: royal chambers
do
	local room = group("Chambers", interior)
	rug(room, PX + 8, UY + 0.12, PZ, 22, 24, C.carpet)
	bed(room, PX + 16, UY, PZ - 8, math.rad(90))
	chair(room, PX + 6, UY, PZ + 8, math.rad(180))
	chair(room, PX + 10, UY, PZ + 8, math.rad(180))
	blockOn(room, PX + 8, UY, PZ + 10, 8, 1.1, 4, C.wood, Enum.Material.WoodPlanks) -- sitting table
	bookshelf(room, PX + 24, UY, PZ + 12, math.rad(90), 8, 10)
	banner(room, PX + 4, UY + 12, PZ - 18, 0)
	chandelier(room, PX + 8, Y1 + 42.5, PZ, 26)
	sconce(room, PX - 8, UY + 7, PZ - 18, math.rad(180))
	sconce(room, PX + 24, UY + 7, PZ, math.rad(90))
	-- partition with a doorway on the north (stair exit) side
	blockOn(room, PX - 4, UY, PZ - 6, 1.2, 8, 24, C.marbleShade)
	-- rail around the stair opening (leave the north edge open as the exit)
	blockOn(room, PX - 14, UY, PZ + 3.5, 0.5, 3.4, 18, C.marble)
	blockOn(room, PX - 20, UY, PZ - 5.5, 12, 3.4, 0.5, C.marble)
end

-- west pavilion + arch bridge over a dip in the island
local pav = group("WestPavilion")
local PVX, PVZ = PX - 150, PZ + 36
blockOn(pav, PVX, Y0, PVZ, 34, 4, 34, C.marbleShade)
hall(pav, PVX, Y0 + 4, PVZ, 26, 18, 26, 8, {
	floorColor = C.wood,
	floorMaterial = Enum.Material.WoodPlanks,
	doors = { e = { w = 10, h = 12 } },
})
do
	local lounge = group("PavilionLounge", pav)
	local pfy = Y0 + 5
	rug(lounge, PVX, pfy + 0.12, PVZ, 12, 12, C.carpetNavy)
	longTable(lounge, PVX, pfy, PVZ, 10, 5)
	chandelier(lounge, PVX, Y0 + 20.5, PVZ, 22)
	sconce(lounge, PVX - 10, pfy + 7, PVZ, math.rad(90))
	openDoors(lounge, PVX + 12.5, pfy, PVZ, math.rad(90), 10, 12)
end
colonnade(pav, PVX - 13, PVZ + 13, PVX + 13, PVZ + 13, Y0 + 22, 9, 6.5, 3)
colonnade(pav, PVX - 13, PVZ - 13, PVX + 13, PVZ - 13, Y0 + 22, 9, 6.5, 3)
colonnade(pav, PVX - 13, PVZ - 13, PVX - 13, PVZ + 13, Y0 + 22, 9, 6.5, 3)
colonnade(pav, PVX + 13, PVZ - 13, PVX + 13, PVZ + 13, Y0 + 22, 9, 6.5, 3)
blockOn(pav, PVX, Y0 + 31, PVZ, 30, 1.5, 30, C.marbleShade)
domeTower(pav, PVX, Y0 + 32.5, PVZ, 11, 5, true, false)
spire(pav, PVX - 16, Y0 + 4, PVZ - 16, 3, 30, 18)
spire(pav, PVX + 16, Y0 + 4, PVZ + 16, 3, 30, 18)

archBridge(group("ArchBridge"), PX - 80, PZ + 36, PVX + 13, PVZ, Y0 + 22, 10, 14, Y0 + 2)

-- keep buildings clear of scatter, and a wide lawn around the palace so the
-- whole silhouette reads (front steps, walls, corner spires, great dome)
local mainFootprint = {
	{ PX - 92, PX + 92, PZ - 70, PZ + 72 },
	{ PVX - 20, PVX + 20, PVZ - 20, PVZ + 20 },
	{ PVX, PX - 78, PZ + 28, PZ + 46 },
}
local palaceLawn = {
	{ PX - 118, PX + 118, PZ - 102, PZ + 115 },
	{ PVX - 20, PVX + 20, PVZ - 20, PVZ + 20 },
	{ PVX, PX - 78, PZ + 28, PZ + 46 },
}
local mainTrees = group("Trees", mainIsland)
forest(mainTrees, mainCfg, mainInside, 42, palaceLawn, 1.2)
dressIsland(group("GroundCover", mainIsland), mainCfg, mainInside, mainFootprint)

-- waterfalls pouring off the main island's underside
local mainFalls = group("Waterfalls", mainIsland)
waterfall(mainFalls, PX - 20, TOP - 30, 118, 170, 5)
waterfall(mainFalls, PX + 60, TOP - 40, 102, 150, 4)
waterfall(mainFalls, -165, TOP - 36, 24, 140, 4)

-- small islets joined to the main island by short grassy necks
local linked = group("LinkedIslets")
local linkedCfgs = {
	{ name = "SouthIslet",     cx = 48,  cy = TOP - 2, cz =  178, R = 24, depth = 52, stretchX = 1.15, stretchZ = 0.9 },
	{ name = "SouthWestIslet", cx = -72, cy = TOP - 6, cz =  148, R = 18, depth = 44, stretchX = 1.1,  stretchZ = 1.05 },
	{ name = "NorthEastIslet", cx = 150, cy = TOP + 4, cz = -118, R = 21, depth = 50, stretchX = 1.05, stretchZ = 0.95 },
	{ name = "NorthWestIslet", cx = -155, cy = TOP - 8, cz = -108, R = 17, depth = 42, stretchX = 1.12, stretchZ = 1.0 },
}
for _, cfg in ipairs(linkedCfgs) do
	local islet, inside = buildIsland(cfg)
	islet.Parent = linked
	local mx, my, mz = rimToward(mainCfg, cfg.cx, cfg.cz, 0.90)
	local ix, iy, iz = rimToward(cfg, mainCfg.cx, mainCfg.cz, 0.72)
	landBridge(group("Neck", islet), mx, my, mz, ix, iy, iz, V * 2.2)
	forest(group("Trees", islet), cfg, inside, math.max(3, math.floor(cfg.R / 6)), nil, 0.95)
	dressIsland(group("GroundCover", islet), cfg, inside)
end

-- spawn point on the island
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(PX, TOP + 0.5, PZ + 95)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = root

---------------------------------------------------------------------------------------
-- SCENE: SECONDARY ISLANDS
---------------------------------------------------------------------------------------
-- large island to the right with twin waterfalls and a ruined temple
local eastCfg = { name = "EastIsland", cx = 320, cy = TOP - 28, cz = 70, R = 78, depth = 140, stretchX = 1.2, stretchZ = 0.9 }
local eastIsland, eastInside = buildIsland(eastCfg)
local temple = group("Temple", eastIsland)
blockOn(temple, eastCfg.cx + 10, eastCfg.cy, eastCfg.cz - 10, 30, 3, 30, C.marbleShade)
colonnade(temple, eastCfg.cx - 2, eastCfg.cz - 22, eastCfg.cx + 22, eastCfg.cz - 22, eastCfg.cy + 3, 9, 6, 3)
colonnade(temple, eastCfg.cx - 2, eastCfg.cz + 2, eastCfg.cx + 22, eastCfg.cz + 2, eastCfg.cy + 3, 9, 6, 3)
domeTower(temple, eastCfg.cx + 10, eastCfg.cy + 3, eastCfg.cz - 10, 8, 10, false, true)
spire(temple, eastCfg.cx - 30, eastCfg.cy, eastCfg.cz + 20, 3, 26, 16)
local eastKeepOff = { { eastCfg.cx - 8, eastCfg.cx + 28, eastCfg.cz - 28, eastCfg.cz + 8 } }
forest(group("Trees", eastIsland), eastCfg, eastInside, 40, eastKeepOff, 1.1)
dressIsland(group("GroundCover", eastIsland), eastCfg, eastInside, eastKeepOff)
local eastFalls = group("Waterfalls", eastIsland)
waterfall(eastFalls, eastCfg.cx - 18, eastCfg.cy - 34, eastCfg.cz + 58, 200, 5)
waterfall(eastFalls, eastCfg.cx + 44, eastCfg.cy - 44, eastCfg.cz + 48, 180, 4)

-- small high island far right
local farCfg = { name = "FarEastIsland", cx = 470, cy = TOP + 26, cz = -50, R = 40, depth = 75, stretchX = 1.1, stretchZ = 1.0 }
local farIsland, farInside = buildIsland(farCfg)
forest(group("Trees", farIsland), farCfg, farInside, 18, nil, 1.0)
dressIsland(group("GroundCover", farIsland), farCfg, farInside)
spire(group("Tower", farIsland), farCfg.cx + 8, farCfg.cy, farCfg.cz - 6, 2.8, 22, 14)

-- island to the far left with twin towers
local westCfg = { name = "WestIsland", cx = -300, cy = TOP - 42, cz = 50, R = 58, depth = 80, stretchX = 1.15, stretchZ = 1.0 }
local westIsland, westInside = buildIsland(westCfg)
local westTowers = group("Towers", westIsland)
blockOn(westTowers, westCfg.cx, westCfg.cy, westCfg.cz, 26, 4, 18, C.marbleShade)
hall(westTowers, westCfg.cx, westCfg.cy + 4, westCfg.cz, 20, 14, 14, 7, { doors = { n = true } })
do
	local den = group("WestDen", westTowers)
	local wy = westCfg.cy + 5
	rug(den, westCfg.cx, wy + 0.12, westCfg.cz, 8, 8, C.carpet)
	longTable(den, westCfg.cx, wy, westCfg.cz, 8, 4)
	chandelier(den, westCfg.cx, westCfg.cy + 16.5, westCfg.cz, 18)
end
domeTower(westTowers, westCfg.cx, westCfg.cy + 18, westCfg.cz, 6, 5, false, false)
spire(westTowers, westCfg.cx - 14, westCfg.cy, westCfg.cz - 10, 3.2, 34, 20)
spire(westTowers, westCfg.cx + 14, westCfg.cy, westCfg.cz + 8, 3.2, 28, 18)
local westKeepOff = { { westCfg.cx - 20, westCfg.cx + 20, westCfg.cz - 16, westCfg.cz + 14 } }
forest(group("Trees", westIsland), westCfg, westInside, 22, westKeepOff, 1.0)
dressIsland(group("GroundCover", westIsland), westCfg, westInside, westKeepOff)
waterfall(group("Waterfalls", westIsland), westCfg.cx + 30, westCfg.cy - 24, westCfg.cz + 36, 120, 4)

-- tiny drifting islets
local tinyCfg = { name = "Islet1", cx = -150, cy = TOP - 95, cz = 170, R = 20, depth = 36 }
local tiny1, tiny1Inside = buildIsland(tinyCfg)
forest(group("Trees", tiny1), tinyCfg, tiny1Inside, 2, nil, 0.9)
dressIsland(group("GroundCover", tiny1), tinyCfg, tiny1Inside)
local tiny2Cfg = { name = "Islet2", cx = 200, cy = TOP + 70, cz = -170, R = 16, depth = 30 }
local tiny2, tiny2Inside = buildIsland(tiny2Cfg)
forest(group("Trees", tiny2), tiny2Cfg, tiny2Inside, 2, nil, 0.8)
dressIsland(group("GroundCover", tiny2), tiny2Cfg, tiny2Inside)

---------------------------------------------------------------------------------------
-- SKY & LIGHTING
---------------------------------------------------------------------------------------
Lighting.ClockTime = 13.5
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(135, 145, 165)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 182)
Lighting.ColorShift_Top = Color3.fromRGB(255, 250, 240)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true

if not Lighting:FindFirstChildOfClass("Sky") then
	local sky = Instance.new("Sky")
	sky.Parent = Lighting
end

local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.36
atmo.Offset = 0.55
atmo.Color = Color3.fromRGB(200, 212, 232)
atmo.Decay = Color3.fromRGB(125, 155, 205)
atmo.Glare = 0.25
atmo.Haze = 2.6
atmo.Parent = Lighting

local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.62
clouds.Density = 0.45
clouds.Color = Color3.fromRGB(242, 246, 255)
clouds.Enabled = true
clouds.Parent = Workspace.Terrain

local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 30
bloom.Threshold = 1.2
bloom.Parent = Lighting

local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
rays.Intensity = 0.08
rays.Spread = 0.6
rays.Parent = Lighting

---------------------------------------------------------------------------------------
-- CAMERA (Studio viewport) & DONE
---------------------------------------------------------------------------------------
local cam = Workspace.CurrentCamera
if cam then
	cam.CFrame = CFrame.lookAt(Vector3.new(110, TOP + 60, 640), Vector3.new(90, TOP + 10, 0))
end

print(("FloatingSkyPalace built: %d parts"):format(partCount))
