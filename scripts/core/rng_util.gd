class_name RngUtil
extends RefCounted
## Utilidades determinísticas (sempre recebem o RNG da seed; nunca usam o
## RNG global, para que o mesmo save gere o mesmo mundo).


static func make(seed_value: int, salt: String = "") -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(seed_value) + ":" + salt)
	return r


## Escolhe uma chave de um dicionário {chave: peso}.
static func weighted_key(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total := 0.0
	for k in weights.keys():
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return weights.keys()[0] if not weights.is_empty() else null
	var roll := rng.randf() * total
	var keys := weights.keys()
	keys.sort()
	for k in keys:
		roll -= maxf(float(weights[k]), 0.0)
		if roll <= 0.0:
			return k
	return keys[keys.size() - 1]


## Escolhe um item de um array de dicionários usando o campo de peso.
static func weighted_item(rng: RandomNumberGenerator, arr: Array, weight_key: String = "weight") -> Variant:
	if arr.is_empty():
		return null
	var total := 0.0
	for it in arr:
		total += maxf(float(it.get(weight_key, 1.0)), 0.0)
	var roll := rng.randf() * total
	for it in arr:
		roll -= maxf(float(it.get(weight_key, 1.0)), 0.0)
		if roll <= 0.0:
			return it
	return arr[arr.size() - 1]


static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]
