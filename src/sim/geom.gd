class_name Geom
extends RefCounted

static func segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o1 := _cross(a, b, c)
	var o2 := _cross(a, b, d)
	var o3 := _cross(c, d, a)
	var o4 := _cross(c, d, b)
	return o1 * o2 < 0.0 and o3 * o4 < 0.0


static func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


static func ordinal(n: int) -> String:
	var suffix := "th"
	var tens := n % 100
	if tens < 11 or tens > 13:
		match n % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [n, suffix]


static func money(amount: int) -> String:
	var sign := ""
	var n := amount
	if n < 0:
		sign = "-"
		n = -n
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return sign + "$" + s + out


static func clock(seconds: float) -> String:
	if seconds < 0.0:
		seconds = 0.0
	var total := int(seconds * 100.0)
	var cs := total % 100
	var s := int(seconds) % 60
	var m := int(seconds) / 60
	return "%d:%02d.%02d" % [m, s, cs]
