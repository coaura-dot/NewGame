class_name LevelConst
extends RefCounted
## Constantes da camada MICRO (salas/fases) e legenda dos templates ASCII.
##
## Toda sala ocupa uma célula de ROOM_W x ROOM_H tiles. As saídas ficam em
## posições padronizadas para que qualquer sala encaixe em qualquer vizinha:
##   L/R: coluna 0/39, linhas 17..20 (no nível do chão, que começa na linha 21)
##   U:   linha 0, colunas 18..21
##   D:   linhas 21..23, colunas 18..21 (com plataforma one-way na linha 23)

const TILE := 8
const ROOM_W := 40
const ROOM_H := 24
const FLOOR_ROW := 21
const EXIT_LR_ROWS := [17, 18, 19, 20]
const EXIT_UD_COLS := [18, 19, 20, 21]

## Legenda
const SOLID := "#"
const EMPTY := "."
const ONE_WAY := "-"
const SPIKE := "^"
const BREAKABLE := "B"
const CRACKED_FLOOR := "Z" ## só quebra com Queda Esmagadora

## Caracteres que viram entidades (e o tile embaixo vira vazio)
const ENTITY_CHARS := {
	"E": "enemy", "F": "flyer", "M": "boss", "C": "chest", "K": "key", "D": "dash_crystal",
	"J": "jump_pad", "S": "saw", "L": "torch", "W": "light_shaft", "P": "spawn", "X": "exit",
	"G": "gate", "T": "lever", "N": "npc", "H": "checkpoint", "O": "falling_platform",
	"R": "relic", "Q": "quest_board", "Y": "rift", "A": "altar", "V": "ability_gate",
	"I": "impulse_orb", "U": "moving_platform", "t": "turret", "s": "saw",
}

const ROOM_TYPES := ["entrance", "exit", "combat", "platforming", "corridor", "puzzle", "treasure",
	"secret", "challenge", "hub", "boss", "shaft", "zigzag"]


static func room_origin(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * ROOM_W, cell.y * ROOM_H)
