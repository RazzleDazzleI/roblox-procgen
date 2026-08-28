--!strict
--[[
	The surface an agent drives this through.

	Each function is one MCP tool. They take plain tables and return plain
	tables — no Instances cross the boundary, because an agent cannot hold a
	reference to one between calls and pretending otherwise produces the exact
	stale-handle bug this whole design avoids.
]]

local Alignment = require(script.Parent.Parent.alignment.Alignment)
local Profile   = require(script.Parent.Parent.alignment.Profile)
local Height    = require(script.Parent.Parent.terrain.Height)
local Writer    = require(script.Parent.Parent.terrain.Writer)
local Cottage   = require(script.Parent.Parent.structures.Cottage)

local Tools = {}

--[[ Build a config table from a plain design spec. This is the "design data,
     not sculpting" boundary: an agent edits numbers, never geometry. ]]
function Tools.buildConfig(spec: any)
	return {
		seed = spec.seed or 1337,
		baseHeight = spec.baseHeight or 40,
		hillAmplitude = spec.hillAmplitude or 14,
		hillScale = spec.hillScale or 220,

		stream = spec.stream and {
			alignment = Alignment.new(spec.stream.pis),
			depth = spec.stream.depth or 9,
			width = spec.stream.width or 8,
			bankWidth = spec.stream.bankWidth or 26,
		} or nil,

		road = spec.road and {
			alignment = Alignment.new(spec.road.pis),
			profile = Profile.new(spec.road.vpis),
			width = spec.road.width or 12,
			shoulder = spec.road.shoulder or 14,
		} or nil,

		pads = spec.pads or {},
	}
end

function Tools.generateTerrain(spec: any): { chunks: number, bounds: any }
	local cfg = Tools.buildConfig(spec)
	local chunks = Writer.generateArea(workspace.Terrain, spec.bounds, cfg, spec.chunkSize)
	return { chunks = chunks, bounds = spec.bounds }
end

--[[ Sample the design height at a point WITHOUT touching the world. Cheap, and
     it lets an agent reason about placement before it writes anything. ]]
function Tools.sampleHeight(spec: any, x: number, z: number): number
	return Height.sample(x, z, Tools.buildConfig(spec))
end

--[[ Read the ACTUAL written surface. Distinct from sampleHeight on purpose:
     one is the design, the other is the world, and confusing them is how you
     end up debugging a defect that only exists in your assumptions. ]]
function Tools.measureSurface(x: number, z: number, yMin: number, yMax: number): number?
	return Writer.measureSurface(workspace.Terrain, x, z, yMin, yMax)
end

function Tools.placeCottage(spec: any, opts: any): { name: string, sitAt: number }
	local y = Tools.measureSurface(opts.x, opts.z, 0, 256) or Tools.sampleHeight(spec, opts.x, opts.z)
	local folder = workspace:FindFirstChild("Village") or Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = workspace

	local m = Cottage.build(folder, {
		width = opts.width or 16,
		depth = opts.depth or 12,
		wallHeight = opts.wallHeight or 10,
		roofPitch = opts.roofPitch or 50,
		position = Vector3.new(opts.x, y, opts.z),
		rotation = opts.rotation,
	})
	return { name = m.Name, sitAt = y }
end

return Tools
