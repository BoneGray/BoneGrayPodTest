extends Resource
class_name AttackProfile

@export_group("Identity")
## 攻击配置的稳定 ID，用于武器数据、日志、存档和调试识别。
@export var profile_id := ""
## 攻击类型。当前玩家武器支持 melee 和 projectile。
@export_enum("melee", "projectile") var attack_type := "melee"
## 播放动画时使用的动作名，例如 attack_first 或 attack_second。
@export var animation_action := "attack_first"

@export_group("Common")
## 本次攻击造成的基础伤害。值为 0 或更小时，回退使用武器或角色默认攻击力。
@export var damage := 0
## 手动点按起手的最小间隔，单位为秒。值为 0 或更小时使用玩家默认手动间隔。
@export var manual_attack_lockout := 0.0
## 长按重复攻击的触发间隔，单位为秒。值为 0 或更小时使用玩家默认重复间隔。
@export var repeat_attack_cooldown := 0.0
## 主攻击输入模式。single_press 只响应单次按下；tap_combo 使用短按缓存和后摇取消；hold_repeat 使用按住自动重复攻击。
@export_enum("single_press", "tap_combo", "hold_repeat") var input_mode := "single_press"
## 按住攻击键是否持续重复触发。inherit 使用武器或空手默认值，enabled/disabled 用于单个攻击方式例外。
@export_enum("inherit", "enabled", "disabled") var repeat_mode := "inherit"
## 本攻击进入按住重复触发前的等待时间，单位为秒。小于 0 时继承武器或空手默认值。
@export var hold_to_repeat_delay := -1.0
## 短按攻击输入缓存时间，单位为秒。攻击未能立刻触发时，会在这段时间内等待可取消窗口或冷却结束。
@export var input_buffer_time := 0.18
## 攻击动画最后几帧允许短按取消后摇并接下一次攻击。0 表示不允许短按取消。
@export var cancel_last_frames := 2

@export_group("Phases")
## 攻击前摇帧。未配置时会根据 hit_frames 自动推导为首个命中帧之前的帧。
@export var startup_frames: Array[int] = []
## 攻击有效帧。未配置时使用 hit_frames；可用于区分有效阶段和实际命中帧。
@export var active_frames: Array[int] = []
## 攻击后摇帧。未配置时会根据 hit_frames 自动推导为最后命中帧之后的帧。
@export var recovery_frames: Array[int] = []

@export_group("Movement")
## 攻击过程中的移动规则。inherit 使用 input_mode 推导；slow_locked_direction 允许减速移动但不转向；slow_turn_to_input 允许减速移动并按输入转向；rooted 表示攻击中不能移动。
@export_enum("inherit", "slow_locked_direction", "slow_turn_to_input", "rooted") var movement_rule := "inherit"

@export_group("Melee")
## 近战攻击在动画第几帧启用命中判定。
@export var hit_frames: Array[int] = [2]
## 近战攻击最多命中的目标数量。值为 0 或更小时表示不限制。
@export var max_targets := 1

@export_group("Projectile Intercept")
## 是否允许本次攻击拦截飞行中的可拦截投射物，例如木棒打落飞斧，或子弹击落飞斧。
@export var can_intercept_projectile := false
## 本次攻击拥有的拦截标签。飞行物的需求标签与这里任意一个标签匹配时，才允许拦截。
@export var intercept_tags: PackedStringArray = []

@export_group("Projectile")
## 弹丸攻击生成的弹丸场景。
@export var projectile_scene: PackedScene
## 弹丸飞行速度，单位为像素/秒。
@export var projectile_speed := 180.0
## 弹丸最长存在时间，单位为秒。
@export var projectile_lifetime := 0.8
## 每次开火生成的弹丸数量。大于 1 时可用于散弹枪、扇形弹幕等武器。
@export var projectile_count := 1
## 多弹丸在基础方向上的总散布角度，单位为度。0 表示不散布。
@export var projectile_spread_degrees := 0.0
## 弹丸会被哪些碰撞层阻挡，通常为地图墙体或障碍层。
@export var projectile_blocked_by_mask := 1
## 弹丸命中墙体后从碰撞点回退的距离，避免视觉上嵌入墙体。
@export var projectile_wall_backoff := 2.0

@export_group("Wall Impact")
## 弹丸命中墙体或障碍后生成的命中特效场景。为空时不生成弹孔。
@export var wall_impact_scene: PackedScene
## 墙体命中特效沿碰撞法线外推的像素距离，避免视觉上嵌入墙体。
@export var wall_impact_offset := 1.0
## 墙体命中特效保持清晰的时间，单位为秒。
@export var wall_impact_hold_time := 4.0
## 墙体命中特效淡出时间，单位为秒。
@export var wall_impact_fade_time := 1.5
## 同时存在的墙体命中特效上限。小于 0 时使用 EffectManager 默认值。
@export var wall_impact_pool_limit := -1

@export_group("Muzzle Flash")
## 弹丸攻击时生成的枪口火焰场景。为空时不播放枪口火焰。
@export var muzzle_flash_scene: PackedScene
## 枪口火焰在角色朝下时的生成偏移，基于角色全局位置。
@export var muzzle_flash_offset_down := Vector2.ZERO
## 枪口火焰在角色朝上时的生成偏移，基于角色全局位置。
@export var muzzle_flash_offset_up := Vector2.ZERO
## 枪口火焰在角色朝右侧时的生成偏移，基于角色全局位置。
@export var muzzle_flash_offset_side := Vector2.ZERO
## 枪口火焰在角色朝左侧时的生成偏移，基于角色全局位置。
@export var muzzle_flash_offset_side_left := Vector2.ZERO
## 同时存在的枪口火焰上限。小于 0 时使用 EffectManager 默认值。
@export var muzzle_flash_pool_limit := -1

@export_group("Casing")
## 弹丸攻击时生成的弹壳场景。为空时不抛出弹壳。
@export var casing_scene: PackedScene
## 弹壳在角色朝下时的生成偏移，基于角色全局位置并叠加当前武器视觉偏移。
@export var casing_offset_down := Vector2.ZERO
## 弹壳在角色朝上时的生成偏移，基于角色全局位置并叠加当前武器视觉偏移。
@export var casing_offset_up := Vector2.ZERO
## 弹壳在角色朝右侧时的生成偏移，基于角色全局位置并叠加当前武器视觉偏移。
@export var casing_offset_side := Vector2.ZERO
## 弹壳在角色朝左侧时的生成偏移，基于角色全局位置并叠加当前武器视觉偏移。
@export var casing_offset_side_left := Vector2.ZERO
## 弹壳弹出的基础速度，单位为像素/秒。
@export var casing_eject_speed := 55.0
## 弹壳弹出速度的随机浮动范围，单位为像素/秒。
@export var casing_speed_variance := 16.0
## 弹壳消失前的飞行动画时间，单位为秒。
@export var casing_lifetime := 0.45
## 同时存在的弹壳上限。小于 0 时使用 EffectManager 默认值。
@export var casing_pool_limit := -1
