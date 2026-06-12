# Gameplay Design

This document records gameplay-facing design decisions and open questions.
Keep detailed implementation rules in `docs/development-guidelines.md`.

## Player Characters And Equipment

Player character logic must not assume every playable character can replace weapons or use tools.
Weapon replacement and tool usage are character capabilities, not mandatory behavior on the base Player.

Future playable characters should be defined by data and optional capability modules.

Recommended character data:

- display name
- base stats
- visual resource
- default combat profile
- optional equipment profile
- whether the character can change weapons
- whether the character can use tools

Recommended rules:

- A character that can change weapons uses an equipment controller.
- A character that cannot change weapons uses its built-in combat profile.
- The combat system should read an attack profile through a shared interface instead of knowing where it came from.

Equipment should be split into weapon equipment and tool equipment.

Weapon equipment controls combat output:

- damage
- cooldown
- attack range
- max hit targets
- hit shape
- knockback
- animation key
- hit effect

Player primary attack input is selected by `AttackProfile.input_mode`.

Each weapon should choose one main input feel instead of mixing short press, tap combo, and hold repeat at the same time:

- `single_press`: one press triggers one attack. This is suitable for handguns, slow tools, or weapons that should not combo.
- `tap_combo`: repeated short presses can chain attacks through input buffering and recovery canceling. This is suitable for unarmed attacks, bats, knives, and other manual melee weapons.
- `hold_repeat`: pressing once fires once, then holding repeats according to cooldown. This is suitable for automatic firearms.

Current player weapon input modes:

- Unarmed: `tap_combo`
- Baseball bat: `tap_combo`
- Automatic gun: `hold_repeat`

Tap combo rules:

- `input_buffer_time` controls how long a short press waits when the attack cannot start immediately.
- `cancel_last_frames` controls how many final animation frames are treated as recovery frames that can be canceled by a buffered short press.
- Recovery canceling should happen after the active hit frames, not during startup or hit confirmation.
- Four-frame attacks should usually start with the last `1` cancel frame; longer attacks can test the last `2` frames.
- Holding the attack key should not automatically repeat a `tap_combo` attack.

Hold repeat rules:

- `hold_to_repeat_delay` controls how long the player must hold before repeated attacks begin.
- The repeated attack interval comes from the current attack `cooldown`.
- Hold repeat should not use short-press input buffering or recovery canceling.
- Hold repeat is a temporary held-input state. Releasing the attack key should clear repeat state, cancel repeat-only animation lock, and restore normal movement speed and turning.
- Automatic firearms should usually set `cancel_last_frames = 0`.

Player weapon combat data should live on `AttackProfile` first:

- `AttackProfile.damage` defines attack damage.
- `AttackProfile.cooldown` defines attack cadence.
- `AttackProfile.input_mode` defines whether the weapon is `single_press`, `tap_combo`, or `hold_repeat`.
- `AttackProfile.repeat_mode` and `hold_to_repeat_delay` define hold-repeat behavior when needed.
- `AttackProfile.startup_frames`, `active_frames`, and `recovery_frames` define the attack phase timeline. If they are empty, runtime may derive phases from `hit_frames` for migration compatibility.
- `AttackProfile.movement_rule` defines movement during attack. Current rules are `slow_locked_direction`, `slow_turn_to_input`, and `rooted`; `inherit` keeps the old input-mode-based fallback.
- `WeaponData.attack_power`, `attack_cooldown`, `repeat_while_held`, and `hold_to_repeat_delay` are migration fallback fields only. New weapons should leave them at defaults and configure the attack profile instead.
- Fourth-step resourceization closeout is tracked in `docs/combat-data-resourceization-closeout.md`.

Tool equipment controls active utility behavior:

- cooldown
- use count or durability
- effect type
- duration
- target rule

Recommended Player structure:

```text
Player
+-- CharacterStats or CharacterDefinition
+-- Health logic
+-- Movement logic
+-- CombatController
+-- EquipmentController optional
+-- VisualController
```

The base Player should not directly hard-code weapon replacement logic.
It should ask an attack-profile provider for current attack data.

Future combat code should use this concept:

```gdscript
func get_attack_profile() -> AttackProfile
```

For equipment characters, the attack profile can come from the current weapon.
For fixed-combat characters, the attack profile can come from the character definition.

Combat code should consume the result only:

```text
damage
cooldown
range
max targets
attack shape
animation key
```

First implementation slice:

1. Add `AttackProfile` resource.
2. Add `CharacterDefinition` resource.
3. Add optional `PlayerEquipment` controller.
4. Make the current player use equipment-backed attack data.
5. Keep fallback built-in attack data for characters without equipment.
6. Add one weapon example and one tool example only.

Do not build full inventory, item rarity, drops, UI, or visual weapon swapping in the first slice unless the gameplay loop requires it.

Open TODO:

- Decide whether tools are active skills, consumables, or both.
- Decide whether weapon visuals are shown on the character or represented only by attack behavior.
- Decide how character selection loads `CharacterDefinition`.
- Decide how equipment data will be saved later.

## Enemy Combat

Enemy combat decisions should be discussed before implementation when they affect playability.

For enemies with multiple attack animations, define the gameplay meaning before wiring code:

- Is the second attack light, heavy, sweeping, ranged, charge, or special?
- How is it selected: fixed pattern, weight, distance, cooldown, target state, enemy phase, or player behavior?
- What differs from the first attack: damage, range, warning time, hit frames, max targets, cooldown, recovery, or movement lock?
- Can the same attack repeat many times, or should the AI avoid repetition?
- Can the player read and react to the attack?

Current note:

- `Zombie Big` has `attack_*_first` and `attack_*_second` animation sets.
- The selection rule should be finalized as a design decision before treating it as stable gameplay.
- Future animation names should follow `动作_方向_补充_其他`, for example `attack_down_first` and `attack_side_second`.
- Existing names can be migrated gradually when we decide to rename animation resources.

Current special attack decision:

- The current enemy feel is treated as the `Normal` baseline: dangerous, readable enough, and close to the prototype feel that already plays well.
- Enemy attack selection should be data-driven before adding Easy or Hard variants. The current baseline uses `attack_selection_order = "special_first"`, `default_attack_weight = 1.0`, `special_attack_weight_multiplier = 1.0`, and `melee_attack_weight_multiplier = 1.0`.
- Enemy `attack_profiles` support both inline `Dictionary` profiles and `EnemyAttackProfile` resources. Runtime code converts both forms into the same dictionary shape before selection and execution.
- Enemy attacks should prefer `.tres` resources once their rules are stable. Current resource-backed attacks include Big/Small default melee, Axe weapon melee, Axe no-weapon melee, Big heavy stun, Small cross, and Axe throw.
- New enemy `attack_actions` should define an explicit `EnemyAttackProfile` resource by default. Inline `Dictionary` profiles are kept only as a migration fallback.
- Existing Big / Small / Axe attack actions are resource-backed as of the fourth-step combat data resourceization closeout.
- Individual attack profiles may use `selection_weight` to tune how often an available attack is selected. A weight of `0` disables selection without removing the profile.
- Individual special attacks may use `special_cooldown` for independent cooldown. The enemy keeps runtime `last_used` data per action, so finishing the current animation does not clear special cooldown.
- Attack profiles may use contextual multipliers such as `repeat_weight_multiplier` and `target_stunned_weight_multiplier`. These change priority only after the attack passes distance, line-of-sight, weapon, and cooldown checks; they must not bypass cooldown.
- If a profile later defines `special_cooldown_min` and `special_cooldown_max`, the current implementation uses `special_cooldown_min` as the fixed cooldown first. Random cooldown ranges should be enabled only after we explicitly decide the enemy needs less mechanical timing.
- Easy and Hard should adjust weights, range, cooldown, and selection order through data first. Do not rewrite enemy AI logic just to create difficulty tiers.
- Normal enemy attacks use `type = "melee"` and keep the existing standing attack flow: choose direction, play animation, enable `AttackArea2D` during hit frames, then apply damage on overlap.
- `Zombie Small` uses `attack_second` as `type = "cross"`.
- `Zombie Small` lowers the weight of immediately repeated cross attacks, but raises the cross priority when the target is stunned. This keeps the attack from feeling spammy while still allowing Big + Small cooperation.
- `Zombie Big` is a slow heavy controller. Its second attack has lower selection weight, independent cooldown, strong repeat suppression, and lower priority when the target is already stunned.
- `Zombie Big` uses `attack_second` as a heavy melee hit that applies `status_effect = "stun"` for a short duration when it lands.
- Melee enemies should prefer the attack slot matching their current relative direction to the player. They should only abandon that slot when they are stuck or not making progress, not merely because a fixed timer elapsed.
- Melee attack startup and melee hit confirmation are separate checks: an enemy may start a melee attack after reaching its reserved attack slot and staying within commit range, even if root-to-target distance is slightly outside the base attack range; actual damage still depends on the attack window and hit shape.
- Cross attack triggers from close or mid range, then moves from one side of the player to the opposite side.
- Cross attack locks the target position at attack start, moves the enemy body through or past that point during the animation, then resolves damage with `hit_detection = "body_motion"` when configured.
- Body-motion hit detection uses the enemy body collision shape swept from the previous physics frame to the current physics frame, so the hit range visually follows the body instead of `AttackArea2D`.
- Cross attack should not continuously home toward the player after it starts. This keeps the attack readable and lets the player dodge.
- After a cross attack, the enemy turns back toward the player so the final turn frames and gameplay direction agree.
- `Zombie Axe` uses `attack_second` as `type = "projectile"`: it throws its axe, loses the weapon after the projectile spawns, then switches to no-axe animations and no-axe melee.
- `Zombie Axe` is a mid-range pressure enemy. Its throw has medium selection weight, independent cooldown, repeat suppression, and a small priority boost when the target is stunned.
- A no-axe enemy should prefer retrieving its own landed weapon unless the player is already close enough to justify a no-axe melee response.
- Enemy thrown weapons are enemy-owned in the current slice; the player cannot pick them up yet.
- Axe thrown weapon pickups are owner-bound. Only the Axe that threw the weapon may register and retrieve that pickup; other Axe enemies must ignore it. If the owner is deactivated or dies, its retrieval target is cleared.
- Current prototype scope supports `melee`, `leap`, `cross`, and simple enemy-owned `projectile`; area, summon, or multi-phase attacks should be added as separate attack profile types later.
