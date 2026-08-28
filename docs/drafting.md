# The drafting methodology

The part of this repo that generalises past the engine.

## Order is the algorithm

Civil design has a fixed sequence, and it turns out to be a better generator
than noise-first because each step constrains the next:

**1. Drainage.** Carve the watercourse before anything else exists. Water is not
a decoration applied at the end — it determines what ground is buildable. Noise
terrain with a river painted on afterwards produces rivers that run uphill and
houses in the floodplain, and no amount of downstream tweaking repairs it.

**2. Corridor.** A road is an *alignment* (horizontal centerline) plus a
*profile* (vertical elevation along it). Both are data. The road surface is a
cross-section swept along that pair, then **daylighted** into surrounding grade
so the cut-and-fill slopes meet existing ground. Skip the daylighting and the
road sits on a plinth with vertical sides.

**3. Pads.** Buildings sit on graded benches derived from the corridor, never
dropped onto raw terrain.

## Stations and offsets

Every position is expressed as *station* (distance along the centerline) and
*offset* (perpendicular distance). This is why the geometry survives editing:
move one PI and everything referenced to that alignment moves coherently. Store
world XYZ instead and a single change orphans every dependent object.

## Grid and datum

Buildings are laid out on a grid with named lines and a datum table of floor
levels, rather than absolute coordinates per part. A wall belongs to grid line
`B` at datum `FFL+0`; if the datum moves, everything referencing it moves.

## Phase gates

Schematic → design development → construction documents. Each phase is allowed
to change only what the previous one left open. The generator equivalent:
massing is fixed before openings are placed, openings before trim. Jumping
straight to detail produces beautiful windows in a building whose proportions
are wrong, and you cannot fix proportion by adding trim.

## Skeleton before skin

From mechanical practice: establish datum planes and the load path first, then
hang geometry on it. A cottage is a frame — sill, posts, plate, rafters — and
the plaster is cladding. Modelling the visible surface first means every
subsequent part is positioned by eye against something arbitrary.
