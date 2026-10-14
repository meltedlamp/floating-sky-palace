--[[
	ParkourConfig  (ModuleScript)  ->  ReplicatedStorage > Parkour > ParkourConfig
	All the tunables for the Assassin's-Creed-style free-running system.
	Both ParkourServer and ParkourClient read this.
]]

return {
	-- movement
	WalkSpeed = 16,
	SprintSpeed = 27,          -- "high profile" free-run speed while Shift is held
	JumpPower = 50,

	-- climbing
	ClimbSpeed = 9,            -- studs/sec along a wall
	ClimbReach = 3.4,          -- how far in front of the chest a wall may be to grab it
	HangDistance = 1.6,        -- distance kept between the root part and the wall while climbing
	WallMaxNormalY = 0.55,     -- surfaces with a steeper-than-this normal count as walls (0 = vertical, 1 = floor)
	WallJumpUp = 48,           -- upward leap velocity when pressing Space + W on a wall
	WallJumpBack = 30,         -- push-off velocity when pressing Space with no / backward input
	SideLeap = 34,             -- sideways leap velocity (Space + A/D)
	MantleTime = 0.5,          -- seconds to pull yourself over a ledge

	-- vaulting / wall running
	VaultMinHeight = 1.5,
	VaultMaxHeight = 6.5,
	WallRunTime = 1.0,
	WallRunSpeed = 30,

	-- falling
	SafeFall = 22,             -- studs you can fall with no damage
	RollFall = 65,             -- up to this height, landing while holding Shift rolls and takes no damage
	DeathFall = 120,           -- from this height, any landing not in hay is fatal
	FallDamagePerStud = 1.5,
	RollSpeed = 24,
	RollTime = 0.55,

	-- ziplines
	ZiplineSpeed = 60,
	ZiplineAccel = 35,
	ZiplineHang = 4.6,         -- how far below the rope the root part hangs
	ZiplineGrabRange = 9,      -- how close to the start post you must be
	ZiplineStartOffset = 2.5,  -- how far along the rope the ride begins (clears the post)

	-- leap of faith
	DiveMinDrop = 15,          -- hay must be at least this far below you
	DiveSearchRadius = 70,     -- and within this horizontal distance, roughly in front of you

	-- viewpoints
	SyncDuration = 3.5,        -- length of the synchronisation camera sweep

	-- keys (gamepad: sprint = L3 / LeftTrigger, interact = X, drop = B)
	Keys = {
		Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonL2 },
		Interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
		Drop = { Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB },
	},
}
