--!strict
--[[
	One height function, composed of layers.

	Everything about the landscape comes from H(x, z). No hand-sculpting
	anywhere — which is what makes a region reproducible: regenerate a chunk and
	you get exactly what was there before, so damage is always undoable.

	Layer order is the whole design, and it follows civil practice rather than
	graphics practice:

	    1. base terrain
	    2. DRAINAGE — carve the stream valley first
	    3. corridor  — road grading follows the water
	    4. pads      — buildings sit on benches derived from the corridor

	Noise-first generation inverts this and produces rivers running uphill and
	houses in floodplains. Water is not a texture you add at the end; it is the
	constraint everything else obeys.
]]

local Alignment = require(script.Parent.Parent.alignment.Alignment)
local Profile = require(script.Parent.Parent.alignment.Profile)

local Height = {}

export type Config = {
	seed: number,
	baseHeight: number,
	hillAmplitude: number,
	hillScale: number,
	stream: { alignment: any, depth: number, width: number, bankWidth: number },
	road: { alignment: any, profile: any, width: number, shoulder: number },
	pads: { { x: number, z: number, radius: number, elevation: number } },
}

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-6), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Layered value noise. Deterministic in the seed, so a chunk always regenerates
-- identically.
local function hills(x: number, z: number, cfg: Config): number
	local h, amp, freq = 0, cfg.hillAmplitude, 1 / cfg.hillScale
	for octave = 1, 4 do
		h += math.noise(x * freq, z * freq, cfg.seed + octave) * amp
		amp *= 0.5
		freq *= 2.07 -- non-integer, or octaves align and grid artefacts appear
	end
	return h
end

function Height.sample(x: number, z: number, cfg: Config): number
	local h = cfg.baseHeight + hills(x, z, cfg)

	-- 1. DRAINAGE FIRST -----------------------------------------------------
	local s = cfg.stream
	if s then
		local _, off = s.alignment:project(x, z)
		local d = math.abs(off)
		if d < s.bankWidth then
			-- V-section: full depth in the channel, easing out to the bank line
			local cut = s.depth * (1 - smoothstep(s.width, s.bankWidth, d))
			h -= cut
		end
	end

	-- 2. ROAD CORRIDOR ------------------------------------------------------
	local r = cfg.road
	if r then
		local station, off = r.alignment:project(x, z)
		local d = math.abs(off)
		local edge = r.width + r.shoulder
		if d < edge then
			local target = r.profile:elevationAt(station)
			-- Full pull to grade across the travelled way, then DAYLIGHT out to
			-- meet existing ground at the shoulder — otherwise the road sits on
			-- a plinth with vertical sides.
			local pull = 1 - smoothstep(r.width, edge, d)
			h += (target - h) * pull
		end
	end

	-- 3. BUILDING PADS ------------------------------------------------------
	for _, pad in ipairs(cfg.pads or {}) do
		local dx, dz = x - pad.x, z - pad.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < pad.radius * 2 then
			local pull = 1 - smoothstep(pad.radius, pad.radius * 2, d)
			h += (pad.elevation - h) * pull
		end
	end

	return h
end

return Height
