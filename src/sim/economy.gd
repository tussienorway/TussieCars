class_name Economy
extends RefCounted


static func entry_fee(tier: String) -> int:
	return int(Balance.num("prizes.%s.fee" % tier, 200))


static func payout(position: int, tier: String, difficulty: String) -> int:
	var prizes: Dictionary = Balance.dict_at("prizes.%s" % tier)
	var table: Array = prizes.get("payouts", [0])
	var index := clampi(position - 1, 0, table.size() - 1)
	var base := int(table[index])
	var mult := Balance.num("difficulties.%s.prize" % difficulty, 1.0)
	return int(round(float(base) * mult))


static func points_for(position: int) -> int:
	Balance.load_data()
	var table: Array = Balance.data.get("points", [10, 6, 4, 2, 1])
	if position < 1 or position > table.size():
		return 0
	return int(table[position - 1])


static func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	var spec: Dictionary = Balance.dict_at("upgrades.%s" % upgrade_id)
	var base := int(spec.get("base_cost", 500))
	return int(round(float(base) * pow(1.72, float(current_level))))


static func repair_cost(missing_hp: float, pit_level: int) -> int:
	var per := Balance.num("repair_per_hp", 6.0)
	var discount := pow(0.9, float(pit_level))
	return int(ceil(max(missing_hp, 0.0) * per * discount))


static func settlement(position: int, tier: String, difficulty: String, fee_paid: int, dnf: bool) -> Dictionary:
	var prize := 0 if dnf else payout(position, tier, difficulty)
	var points := 0 if dnf else points_for(position)
	return {
		"prize": prize,
		"fee": fee_paid,
		"net": prize - fee_paid,
		"points": points,
	}
