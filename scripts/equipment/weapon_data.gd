extends Resource
class_name WeaponData

@export_group("Identity")
## 武器的稳定 ID，用于存档、配置和代码识别。建议使用小写英文和下划线。
@export var weapon_id := ""
## 武器显示名称，后续可用于 UI、日志或调试面板。
@export var display_name := "Weapon"
## 武器大类。当前支持 melee 和 firearm，用于决定默认攻击执行方式。
@export_enum("melee", "firearm") var weapon_type := "melee"

@export_group("Visual")
## 武器掉落在地面时显示的静态贴图。
@export var world_texture: Texture2D
## 武器在物品栏或 UI 中显示的图标。
@export var icon_texture: Texture2D
## 装备到玩家手部层时使用的 SpriteFrames，动画名需要与玩家动作动画保持一致。
@export var visual_sprite_frames: SpriteFrames
## 装备视觉层在角色朝下时的像素偏移，用于微调手部或武器遮挡。
@export var visual_offset_down := Vector2.ZERO
## 装备视觉层在角色朝上时的像素偏移，用于微调手部或武器遮挡。
@export var visual_offset_up := Vector2.ZERO
## 装备视觉层在角色朝右侧时的像素偏移，用于微调手部或武器遮挡。
@export var visual_offset_side := Vector2.ZERO
## 装备视觉层在角色朝左侧时的像素偏移，用于微调手部或武器遮挡。
@export var visual_offset_side_left := Vector2.ZERO
## 按完整动画名追加的装备视觉层像素偏移。键使用动画名，例如 idle_down、attack_side_first；值为 Vector2。
@export var animation_visual_offsets := {}

@export_group("Attack")
## 武器丢弃或放置在地面时生成的拾取物场景路径。使用路径避免 WeaponData 与 Pickup 场景循环引用。
@export_file("*.tscn") var pickup_scene_path := ""
## 主攻击配置，通常对应 J 键。
@export var primary_attack_profile: Resource
## 副攻击配置，通常对应 K 键。为空时使用主攻击配置或角色默认逻辑。
@export var secondary_attack_profile: Resource
## 武器攻击力。值为 0 或更小时，玩家会回退使用自身默认攻击力。
@export var attack_power := 0
## 武器攻击冷却，单位为秒。值为 0 或更小时，玩家会回退使用自身默认冷却。
@export var attack_cooldown := 0.0
## 武器默认是否允许按住攻击键持续重复触发。单个 AttackProfile 可用 repeat_mode 覆盖。
@export var repeat_while_held := false
## 按住攻击键多久后进入持续重复触发，单位为秒。短按会立即攻击一次，但不会进入连击。
@export var hold_to_repeat_delay := 0.22
