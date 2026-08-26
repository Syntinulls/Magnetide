extends RefCounted
class_name PhysicsLayers

## The 2D physics layers, as bit indices. Mirrors project.godot [layer_names].
##
## Code names a layer and shifts: `1 << PhysicsLayers.ENEMIES`, so a mask reads as the
## layers it contains rather than as an integer nobody can decode at a glance. Combine
## with `|`.
##
## These are zero-based bit indices, not the 1-based numbers the Godot inspector shows:
## layer 1 in the editor is index 0 here. Scene files still carry plain integers — a
## .tscn cannot reference a constant — so the editor's named checkboxes are the place to
## set a layer on an authored node, and this is the place to set one in code.

const BOUNDARIES := 0
const SALVAGE_ITEMS := 1
const ENEMIES := 2
const PLAYER_HITBOX := 3
const PLAYER_BODY := 4
const STORAGE_BORDERS := 5
const INTERACTABLES := 6
