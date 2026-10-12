class_name CarSim
extends RefCounted

const HALF_LEN := 15.0
const HALF_WID := 9.0


static func integrate(car: CarState, input: Dictionary, delta: float, surf: Dictionary) -> void:
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	var fspeed := car.vel.dot(forward)
	var lspeed := car.vel.dot(right)
	var damage_mul := 1.0
	if car.hp < car.max_hp * 0.7:
		damage_mul = lerpf(0.62, 1.0, clampf(car.hp / maxf(car.max_hp * 0.7, 1.0), 0.0, 1.0))
	var throttle := float(input.get("throttle", 0.0))
	var brake_in := float(input.get("brake", 0.0))
	var steer := float(input.get("steer", 0.0))
	var reversing := bool(input.get("reverse", false))
	var engine := car.accel * damage_mul
	var drive := 0.0
	if reversing:
		drive -= Balance.num("physics.reverse_accel", 320.0)
	elif throttle > 0.0:
		drive += engine * throttle
	if brake_in > 0.0 and not reversing:
		if fspeed > 8.0:
			drive -= car.brake * brake_in
		else:
			drive -= engine * 0.45 * brake_in
	var want_boost := bool(input.get("boost", false)) and throttle > 0.2 and not reversing
	var can_boost := car.boost > 0.02 and (car.boosting or car.boost >= Balance.num("boost.min_start", 0.12))
	car.boosting = want_boost and can_boost
	car.drifting = bool(input.get("drift", false)) and absf(fspeed) > Balance.num("drift.min_speed", 150.0) and absf(steer) > 0.28 and not reversing
	car.drafting = bool(input.get("draft", false)) and absf(fspeed) > 110.0 and not reversing
	var max_s := car.max_speed * damage_mul
	if car.boosting:
		drive += Balance.num("boost.extra_accel", 360.0)
		max_s *= Balance.num("boost.speed_mul", 1.15)
		car.boost = maxf(0.0, car.boost - Balance.num("boost.drain", 0.5) * delta)
	else:
		car.boost = minf(1.0, car.boost + Balance.num("boost.regen", 0.1) * delta)
		if car.drifting:
			car.boost = minf(1.0, car.boost + Balance.num("drift.fill", 0.32) * delta)
		if car.drafting:
			car.boost = minf(1.0, car.boost + Balance.num("slipstream.fill", 0.16) * delta)
	if car.drafting:
		max_s *= Balance.num("slipstream.speed_mul", 1.06)
	var grip_mul := 1.0
	if car.drifting:
		grip_mul *= Balance.num("drift.grip_mul", 0.55)
	var lat_grip := 1.0
	if car.boosting:
		lat_grip *= Balance.num("boost.grip_mul", 0.86)
	# Friction circle: longitudinal and lateral force share one grip budget.
	# The budget shrinks with speed, so a flat-out corner asks for more yaw
	# than the tyres can give. Braking while turning spends the same budget.
	var mu := _surface_mu(car, surf, grip_mul, Vector2(fspeed, lspeed).length(), max_s)
	var a_peak := Balance.num("physics.lat_accel", 640.0) * mu
	var steer_abs := clampf(absf(steer), 0.0, 1.0)
	var long_share := sqrt(maxf(0.0, 1.0 - steer_abs * steer_abs * 0.72))
	var long_cap := a_peak * maxf(long_share, 0.28)
	drive = clampf(drive, -long_cap, long_cap)
	var transfer := clampf(drive / maxf(a_peak, 1.0), -1.0, 1.0)
	car.load = transfer
	fspeed += drive * delta
	if str(surf.get("id", "")) == "N" and not reversing:
		fspeed += Balance.num("pad.push", 150.0) * delta
		car.boost = minf(1.0, car.boost + Balance.num("pad.fill", 1.6) * delta)
	fspeed = clampf(fspeed, -Balance.num("physics.reverse_max", 160.0), max_s)
	if throttle <= 0.0 and brake_in <= 0.0 and not reversing:
		var roll := Balance.num("physics.rolling", 18.0) * delta
		if absf(fspeed) <= roll:
			fspeed = 0.0
		else:
			fspeed -= signf(fspeed) * roll
	var drag := Balance.num("physics.drag", 0.18) + float(surf.get("drag", 0.2))
	if car.drafting:
		drag *= Balance.num("slipstream.drag_mul", 0.68)
	fspeed *= exp(-drag * delta)
	var xfer := Balance.num("physics.load_transfer", 0.55)
	var lat_scale := 1.0
	var yaw_scale := 1.0
	if transfer < 0.0:
		lat_scale = lerpf(1.0, 1.0 - xfer * 0.5, -transfer)
		yaw_scale = lerpf(1.0, 1.0 + xfer * 0.45, -transfer)
	elif transfer > 0.0:
		yaw_scale = lerpf(1.0, 1.0 - xfer * 0.55, transfer)
		lat_scale = lerpf(1.0, 1.0 - xfer * 0.18, transfer)
	var lat_budget := a_peak * lat_scale * lat_grip
	var lat_left := sqrt(maxf(0.0, lat_budget * lat_budget - drive * drive))
	var kill := minf(absf(lspeed), lat_left * delta)
	lspeed -= signf(lspeed) * kill
	if car.drifting:
		lspeed += steer * absf(fspeed) * Balance.num("drift.slide", 0.42) * delta
	fspeed -= absf(lspeed) * 0.45 * delta
	var speed_ratio := clampf(absf(fspeed) / maxf(max_s, 1.0), 0.0, 1.0)
	var high := Balance.num("physics.high_speed_turn", 0.32)
	var turn := steer * car.turn_rate * lerpf(1.0, high, speed_ratio) * yaw_scale
	if car.drifting:
		turn *= Balance.num("drift.yaw_mul", 1.75)
	if absf(fspeed) < 34.0:
		turn *= absf(fspeed) / 34.0
	var demand := absf(fspeed) * absf(turn)
	var slip := 0.0
	if demand > lat_left and absf(fspeed) > 36.0:
		var allowed := lat_left / absf(fspeed)
		var excess := maxf(0.0, absf(turn) - allowed)
		var keep := 0.28 if car.drifting else 0.06
		turn = signf(turn) * (allowed + excess * keep)
		slip = clampf((demand / maxf(lat_left, 1.0)) - 1.0, 0.0, 1.0)
		lspeed += steer * absf(fspeed) * slip * Balance.num("physics.slip_push", 0.9) * delta
	else:
		slip = clampf(demand / maxf(lat_left, 1.0), 0.0, 1.0) * 0.4
	var leftover := absf(lspeed) / maxf(absf(fspeed) + absf(lspeed), 1.0)
	if car.drifting:
		slip = maxf(slip, 0.7)
	car.slip = maxf(slip, clampf(leftover * 1.35, 0.0, 1.0))
	var turn_sign := -1.0 if fspeed < -8.0 else 1.0
	car.heading = wrapf(car.heading + turn * delta * turn_sign, -PI, PI)
	forward = Vector2.from_angle(car.heading)
	right = Vector2(-forward.y, forward.x)
	car.vel = forward * fspeed + right * lspeed
	if float(surf.get("damage", 0.0)) > 0.0:
		car.hp -= float(surf["damage"]) * delta * car.damage_taken
	car.hit_cd = maxf(0.0, car.hit_cd - delta)
	car.cd_missile = maxf(0.0, car.cd_missile - delta)
	car.cd_rear = maxf(0.0, car.cd_rear - delta)
	car.cd_mine = maxf(0.0, car.cd_mine - delta)


# Grip coefficient. car.grip stays the garage stat (about 8.2 stock) and is
# scaled back to a friction multiplier. Speed cuts the circle so a corner
# taken flat exceeds the tyres; lifting or braking brings the grip back.
static func _surface_mu(car: CarState, surf: Dictionary, grip_mul: float, speed: float, max_s: float) -> float:
	var ref := maxf(Balance.num("physics.grip", 8.2), 0.01)
	var stat := car.grip / ref
	var surf_g := float(surf.get("grip", 1.0))
	var ratio := clampf(speed / maxf(max_s, 1.0), 0.0, 1.15)
	var floor_g := Balance.num("physics.speed_grip", 0.34)
	var speed_g := lerpf(1.0, floor_g, pow(minf(ratio, 1.0), 1.1))
	return maxf(0.04, stat * surf_g * grip_mul * speed_g)


static func move(car: CarState, delta: float, track: TrackData, damage_scale: float) -> float:
	var dist := car.vel.length() * delta
	var steps := clampi(int(dist / 6.0) + 1, 1, 8)
	var sub := delta / float(steps)
	var hardest := 0.0
	var touched := false
	var speed_in := car.vel.length()
	for _i in steps:
		var nxt := car.pos + car.vel * sub
		var impact := _try_move(car, nxt, track)
		if not car.pos.is_equal_approx(nxt):
			touched = true
		if impact > hardest:
			hardest = impact
	var threshold := Balance.num("wall_threshold", 85.0)
	if hardest > threshold and car.hit_cd <= 0.0:
		car.hp -= wall_damage(hardest, damage_scale) * car.damage_taken
		car.hit_cd = 0.4
	elif touched and speed_in > 150.0:
		car.hp -= scrape_damage(speed_in, delta, damage_scale) * car.damage_taken
	return hardest


static func scrape_damage(speed: float, delta: float, scale: float = 0.1) -> float:
	var per_unit := scale / maxf(Balance.num("wall_damage", 0.1), 0.001)
	return Balance.num("wall_scrape", 7.0) * clampf(speed / 450.0, 0.0, 1.5) * delta * per_unit


static func wall_damage(impact: float, scale: float) -> float:
	return maxf(impact - 60.0, 0.0) * scale


static func _try_move(car: CarState, nxt: Vector2, track: TrackData) -> float:
	var old := car.pos
	var old_vel := car.vel
	car.pos = nxt
	if not _penetrates(car, track):
		return 0.0
	car.pos = Vector2(nxt.x, old.y)
	var hit_x := _penetrates(car, track)
	if hit_x:
		car.pos.x = old.x
	car.pos.y = nxt.y
	var hit_y := _penetrates(car, track)
	if hit_y:
		car.pos.y = old.y
	var impact := 0.0
	if hit_x:
		impact = maxf(impact, absf(old_vel.x))
		car.vel.x = -old_vel.x * 0.2
	if hit_y:
		impact = maxf(impact, absf(old_vel.y))
		car.vel.y = -old_vel.y * 0.2
	car.vel *= 0.84
	if _penetrates(car, track):
		car.pos = old
		car.vel = Vector2.ZERO
		impact = maxf(impact, old_vel.length())
	return impact


static func separate(a: CarState, b: CarState, damage_scale: float) -> void:
	if a.dnf and b.dnf:
		return
	var delta := a.pos - b.pos
	var dist := delta.length()
	var min_d := 28.0
	if dist >= min_d:
		return
	var normal := Vector2.RIGHT
	if dist > 0.001:
		normal = delta / dist
	else:
		dist = 0.001
	var push := (min_d - dist) * 0.5
	a.pos += normal * push
	b.pos -= normal * push
	var rel := (b.vel - a.vel).dot(normal)
	if rel > 0.0:
		var impulse := rel * 0.55
		a.vel += normal * impulse
		b.vel -= normal * impulse
		if rel > 90.0:
			if a.hit_cd <= 0.0:
				a.hp -= rel * damage_scale * 0.65 * a.damage_taken
				a.hit_cd = 0.28
			if b.hit_cd <= 0.0:
				b.hp -= rel * damage_scale * 0.65 * b.damage_taken
				b.hit_cd = 0.28


static func _penetrates(car: CarState, track: TrackData) -> bool:
	for point in _samples(car):
		if track.blocking(point):
			return true
	return false


static func _samples(car: CarState) -> Array:
	var forward := Vector2.from_angle(car.heading)
	var right := Vector2(-forward.y, forward.x)
	return [
		car.pos,
		car.pos + forward * HALF_LEN,
		car.pos - forward * HALF_LEN,
		car.pos + right * HALF_WID,
		car.pos - right * HALF_WID,
		car.pos + forward * HALF_LEN + right * HALF_WID,
		car.pos + forward * HALF_LEN - right * HALF_WID,
		car.pos - forward * (HALF_LEN * 0.6) + right * HALF_WID,
		car.pos - forward * (HALF_LEN * 0.6) - right * HALF_WID,
	]
