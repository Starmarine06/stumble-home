class_name PartsShop
extends RefCounted
## What the car parts cost. Priced so a night of deliveries alone cannot pay for them,
## and neither can a lucky streak at the casino without deliveries behind it.

## Same order as Game.PART_NAMES.
const PRICES := [1400, 900, 600, 1100]


static func price(i: int) -> int:
	return PRICES[i] if i >= 0 and i < PRICES.size() else 0


static func total() -> int:
	var t := 0
	for p in PRICES:
		t += p
	return t
