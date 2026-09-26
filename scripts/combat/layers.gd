class_name Layers
extends RefCounted
## Bits de colisão (ver [layer_names] no project.godot).

const WORLD := 1
const ACTORS := 2
const HURTBOX := 4
const HITBOX := 8
const INTERACT := 16
const ONE_WAY := 32
const PROJECTILE := 64

enum Team { PLAYER = 0, ENEMY = 1, NEUTRAL = 2 }
