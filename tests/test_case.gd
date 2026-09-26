class_name TestCase
extends RefCounted
## Base dos testes. Métodos que começam com test_ são executados pelo runner.

var runner: Node = null
var tree: SceneTree = null


func check(cond: bool, msg: String = "") -> bool:
	runner.report(cond, msg)
	return cond


func eq(a: Variant, b: Variant, msg: String = "") -> bool:
	var ok := a == b
	runner.report(ok, "%s (esperado %s, veio %s)" % [msg, str(b), str(a)])
	return ok


func near(a: float, b: float, tol: float, msg: String = "") -> bool:
	var ok := absf(a - b) <= tol
	runner.report(ok, "%s (esperado %.3f±%.3f, veio %.3f)" % [msg, b, tol, a])
	return ok
