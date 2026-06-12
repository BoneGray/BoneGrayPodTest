class_name RenderLayers
extends RefCounted

## 地形底板层：地板、草地、马路、河流等不参与 YSort 的地面材质。
const TERRAIN_Z := -100

## 世界 YSort 层：玩家、敌人、拾取物、树干、墙体、车辆等按地面原点排序。
const WORLD_Y_SORT_Z := 0

## 世界效果层：飞行中的子弹、斧子、枪口火光、命中特效等短生命周期表现。
const WORLD_EFFECTS_Z := 50

## 高层覆盖层：树冠、屋顶、天花板、天空遮挡等固定压在世界排序层上方的内容。
const HIGH_OVERLAY_Z := 100

## UI 层：血条、按钮、背包、调试面板等界面内容。
const UI_Z := 1000

## 角色根节点默认世界排序层。角色根节点应参与 WorldActors 的 YSort。
const CHARACTER_ROOT_Z := 0

## 角色阴影层，位于角色身体下方但仍随角色移动。
const CHARACTER_SHADOW_Z := -2

## 角色背后装备层，例如面向上时位于身体后面的手部或武器。
const CHARACTER_BACK_EQUIPMENT_Z := -1

## 角色身体基准层。
const CHARACTER_BODY_Z := 0

## 角色前景装备层，例如面向下或侧面时位于身体前面的手部或武器。
const CHARACTER_FRONT_EQUIPMENT_Z := 0

## 角色内部攻击特效层。不能用于压过同一 WorldActors 下的其他世界对象。
const CHARACTER_ATTACK_EFFECT_Z := 0

## 地面拾取物根节点默认世界排序层，应和角色根节点一致。
const PICKUP_ROOT_Z := 0

## 飞行物飞行中的表现层，通常放在 WorldEffects。
const PROJECTILE_FLYING_Z := 0

## 飞行物落地后的表现层，应切换到 WorldActors 并恢复同层 YSort。
const PROJECTILE_DROPPED_Z := 0
