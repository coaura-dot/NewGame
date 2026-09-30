class_name BlobTable
extends RefCounted
## GERADO por tools/build_tiles.py: máscara canônica de 8 vizinhos
## (N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128; 1 = sólido) -> índice
## do tile no atlas; VARIANTS = índices extras dos formatos comuns.

const INDEX := {0: 0, 1: 1, 4: 2, 5: 3, 7: 4, 16: 5, 17: 6, 20: 7, 21: 8, 23: 9, 28: 10, 29: 11, 31: 12, 64: 13, 65: 14, 68: 15, 69: 16, 71: 17, 80: 18, 81: 19, 84: 20, 85: 21, 87: 22, 92: 23, 93: 24, 95: 25, 112: 26, 113: 27, 116: 28, 117: 29, 119: 30, 124: 31, 125: 32, 127: 33, 193: 34, 197: 35, 199: 36, 209: 37, 213: 38, 215: 39, 221: 40, 223: 41, 241: 42, 245: 43, 247: 44, 253: 45, 255: 46}
const VARIANTS := {124: [47, 48, 49], 199: [50, 51, 52], 31: [53, 54, 55], 241: [56, 57, 58]}
const BREAKABLE := 59
const BG := 61
const COLS := 8


static func canon(mask: int) -> int:
	var m := mask
	if not (mask & 1 and mask & 4):
		m &= ~2
	if not (mask & 16 and mask & 4):
		m &= ~8
	if not (mask & 16 and mask & 64):
		m &= ~32
	if not (mask & 1 and mask & 64):
		m &= ~128
	return m


static func coord(i: int) -> Vector2i:
	return Vector2i(i % COLS, i / COLS)
