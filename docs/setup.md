# Setup

## Requirements
- Roblox Studio
- An MCP-capable host, if you want an agent to drive it

## Studio

1. Copy `src/` into `ServerScriptService` as a folder named `procgen`.
2. Enable **Studio as MCP server** (Plugins tab) if driving from an agent.
3. Run the example from the command bar:

```lua
local Tools = require(game.ServerScriptService.procgen.agent.Tools)

local spec = {
    seed = 1337,
    baseHeight = 40,
    bounds = { minX = -320, minZ = -320, maxX = 320, maxZ = 320 },
    stream = { pis = {{x=-320,z=-80},{x=-40,z=-10},{x=180,z=40},{x=320,z=90}}, depth = 9 },
    road   = {
        pis  = {{x=-300,z=60},{x=-40,z=30},{x=140,z=70},{x=300,z=40}},
        vpis = {
            { station = 0,   elevation = 44 },
            { station = 280, elevation = 52, curveLength = 90 },
            { station = 600, elevation = 46 },
        },
    },
    pads = { { x = 40, z = 90, radius = 26, elevation = 50 } },
}

Tools.generateTerrain(spec)
Tools.placeCottage(spec, { x = 40, z = 90, rotation = math.rad(180) })
```

## Verifying a build

```lua
local Cottage = require(game.ServerScriptService.procgen.structures.Cottage)
assert(Cottage.selfTest(workspace))   -- catches an inverted gable
```

To check what actually landed on the ground, use `Tools.measureSurface` — it
reads voxels. **Do not raycast**; see the note at the top of `terrain/Writer.luau`.

## Regenerating after damage

Every surface comes from `Height.sample`, so a damaged region is repaired by
regenerating that chunk with the same spec. There is no hand-sculpted state to
lose.
