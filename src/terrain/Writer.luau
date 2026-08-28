--!strict
--[[
	Chunked voxel writes.

	Two hard-won rules live here.

	CHUNK THE WRITES. One enormous WriteVoxels is fragile and unrecoverable —
	if it fails halfway you cannot tell what landed. In fixed chunks a damaged
	region is repaired by regenerating that chunk alone.

	NEVER RAYCAST TO CHECK YOUR WORK. Immediately after a voxel write, raycasts
	against terrain return stale collision data while ReadVoxels is already
	correct. I lost hours to a terrain defect that did not exist. ReadVoxels is
	the only ground truth in the same session as a write.
]]

local Height = require(script.Parent.Height)

local Writer = {}

local RESOLUTION = 4 -- studs per voxel; Terrain:WriteVoxels is fixed at 4

function Writer.generateChunk(terrain: Terrain, minX: number, minZ: number,
	sizeX: number, sizeZ: number, cfg: any, yMin: number, yMax: number)

	local region = Region3.new(
		Vector3.new(minX, yMin, minZ),
		Vector3.new(minX + sizeX, yMax, minZ + sizeZ)
	):ExpandToGrid(RESOLUTION)

	local size = region.Size / RESOLUTION
	local nx, ny, nz = math.floor(size.X), math.floor(size.Y), math.floor(size.Z)

	local materials, occupancies = {}, {}
	local origin = region.CFrame.Position - region.Size / 2

	for ix = 1, nx do
		materials[ix], occupancies[ix] = {}, {}
		local wx = origin.X + (ix - 0.5) * RESOLUTION

		for iy = 1, ny do
			materials[ix][iy], occupancies[ix][iy] = {}, {}
			local wy = origin.Y + (iy - 0.5) * RESOLUTION

			for iz = 1, nz do
				local wz = origin.Z + (iz - 0.5) * RESOLUTION
				local surface = Height.sample(wx, wz, cfg)

				-- Partial occupancy on the boundary voxel is what removes the
				-- staircase; a binary fill always reads as a heightmap.
				local fill = math.clamp((surface - wy) / RESOLUTION + 0.5, 0, 1)

				local material = Enum.Material.Grass
				if fill > 0 then
					if wy < surface - 6 then
						material = Enum.Material.Rock
					elseif cfg.stream then
						local _, off = cfg.stream.alignment:project(wx, wz)
						if math.abs(off) < cfg.stream.width then
							material = Enum.Material.Mud
						end
					end
				end

				materials[ix][iy][iz] = material
				occupancies[ix][iy][iz] = fill
			end
		end
	end

	terrain:WriteVoxels(region, RESOLUTION, materials, occupancies)
	return region
end

--[[ Generate a whole area as a grid of chunks. 160 studs is a good size: large
     enough that the call overhead is irrelevant, small enough to redo cheaply. ]]
function Writer.generateArea(terrain: Terrain, bounds: { minX: number, minZ: number, maxX: number, maxZ: number },
	cfg: any, chunkSize: number?)

	local step = chunkSize or 160
	local written = 0

	for x = bounds.minX, bounds.maxX - 1, step do
		for z = bounds.minZ, bounds.maxZ - 1, step do
			local sx = math.min(step, bounds.maxX - x)
			local sz = math.min(step, bounds.maxZ - z)
			Writer.generateChunk(terrain, x, z, sx, sz, cfg, cfg.baseHeight - 64, cfg.baseHeight + 96)
			written += 1
		end
	end
	return written
end

--[[ Verify a written surface. Reads voxels — never raycasts — for the reason
     documented at the top of this file. ]]
function Writer.measureSurface(terrain: Terrain, x: number, z: number, yMin: number, yMax: number): number?
	local region = Region3.new(
		Vector3.new(x - RESOLUTION, yMin, z - RESOLUTION),
		Vector3.new(x + RESOLUTION, yMax, z + RESOLUTION)
	):ExpandToGrid(RESOLUTION)

	local _, occupancies = terrain:ReadVoxels(region, RESOLUTION)
	local sizeY = #occupancies[1]
	local originY = region.CFrame.Position.Y - region.Size.Y / 2

	for iy = sizeY, 1, -1 do
		if occupancies[1][iy][1] > 0.5 then
			return originY + (iy - 0.5) * RESOLUTION
		end
	end
	return nil
end

return Writer
