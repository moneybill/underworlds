class_name MonsterSounds
extends RefCounted
## The sounds each monster makes in a fight, by id in Data.MONS. A monster can have several sounds
## for an event, and one is picked at random. An event with no sounds is simply silent, so these fill
## in over time: add the file as assets/audio/monsters/<monster>_<event>_<n>.wav and list it here.

const IDLE := "idle"  # now and then, while the party decides what to do
const ATTACK := "attack"  # it makes a melee attack
const HIT := "hit"  # it takes damage and lives
const DEATH := "death"  # it dies
## When one act sets off several events, as a spell on a whole group can, the first of these with a
## sound is the one heard.
const LOUDEST_FIRST := [DEATH, HIT, ATTACK]

const BY_MONSTER := {
	"SLIME": {
		ATTACK: [
			preload("res://assets/audio/monsters/slime_attack_1.wav"),
			preload("res://assets/audio/monsters/slime_attack_2.wav"),
			preload("res://assets/audio/monsters/slime_attack_3.wav"),
			preload("res://assets/audio/monsters/slime_attack_4.wav"),
		],
	},
}


## The sounds to choose from for what just happened: events are {id, event}.
static func for_events(events: Array, table: Dictionary = BY_MONSTER) -> Array:
	for wanted in LOUDEST_FIRST:
		for e in events:
			if e["event"] == wanted:
				var streams: Array = table.get(e["id"], {}).get(wanted, [])
				if not streams.is_empty():
					return streams
	return []


## The idle sounds of all these monsters together.
static func idle_for(ids: Array, table: Dictionary = BY_MONSTER) -> Array:
	var streams := []
	for id in ids:
		streams.append_array(table.get(id, {}).get(IDLE, []))
	return streams
