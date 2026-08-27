# roblox-procgen

Procedural terrain and settlement generation driven by an LLM agent, using drafting methodology instead of noise.

An agent connected to a 3D editor over MCP builds a coherent landscape and a village on it — from design-data tables, not from hand-placement and not from raw Perlin noise.

📷 *Screenshots in `docs/images/`*

---

## The idea

Most procedural terrain is noise with a threshold: it produces something that looks like landscape but doesn't hold up, because rivers run uphill, roads cut through where nothing could be built, and settlements sit in floodplains.

Real civil engineering solves this in a fixed order, and that order turns out to be a better generation algorithm than the noise-first approach:

1. **Drainage first.** Carve the stream valley before anything else. Water defines the terrain; it can't be retrofitted.
2. **Corridor next.** Roads follow an alignment — a centerline of points with a vertical profile — swept along the surface, then *daylighted* into the surrounding grade so cut-and-fill slopes actually meet the ground.
3. **Pads last.** Buildings sit on graded benches derived from the corridor, not dropped onto raw terrain.

Everything derives from **one height function** `H(x, z)` composed of layers: base hills → village bench → carved stream → road corridor → building pads. Each layer is a table of parameters, so regenerating a region is deterministic and damage is undoable by re-running that chunk. There is no manual sculpting anywhere.

## What's in here

| | |
|---|---|
| `terrain/` | The layered height function, and chunked voxel writes |
| `alignment/` | Station-offset centerline engine with parabolic vertical curves |
| `corridor/` | Cross-section sweep along an alignment, with daylighting into existing grade |
| `structures/` | Parametric buildings — timber-framed cottages, gabled roofs, a chapel |
| `agent/` | The MCP tool surface the agent drives all of this through |

## Things that turned out to matter

**Voxel reads and raycasts disagree.** Immediately after a voxel write, raycasts against the terrain return stale collision data while the voxel read is correct. I lost hours chasing a terrain defect that didn't exist. Any code sampling a surface right after modifying it has to read voxels, not cast rays.

**Chunk your writes.** Writing a large region in one call is fragile and unrecoverable. In 160-stud chunks it's restartable, and a damaged region is fixed by regenerating that chunk alone.

**Gabled roofs have an orientation trap.** Two wedges form a gable only if their *tall* edges meet at the ridge. Get it backwards and you build a valley that channels water into the house — visually obvious, but only once you look from the right angle. Worth a unit test on the CFrame math rather than an eyeball check.

**Derive placement from a live measurement.** Anything attached to a structure resolves its anchor at build time from the parent's actual transform. Cached coordinates go stale the moment a human moves something in the shared editor — this is the single most common source of "floating" props.

**AI-generated meshes have arbitrary pivots.** Normalize every imported mesh to its *mating* surface at intake — back-center for anything wall-mounted — then place it. Skipping this means every placement is a manual nudge.

## Running it

Requires Roblox Studio with MCP enabled. `docs/setup.md` covers the bridge.

```lua
local Terrain = require(script.Parent.terrain)
Terrain.generate({ region = "village", chunkSize = 160 })
```

## Stack

Luau · Roblox Studio MCP · Node.js agent host

## Notes

The methodology reference in `docs/drafting.md` — grid-and-datum layout, phase gates, corridor daylighting — is distilled from architectural, civil, and mechanical drafting practice. It's the part that generalizes beyond this engine.
