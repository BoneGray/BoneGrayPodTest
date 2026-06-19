# 渲染层级迁移流程

本文定义图层系统的修订流程，避免为了某一个测试场景写特例。`navigation_obstacle_test_scene` 是当前主力样板场景，后续主场景和新场景都应按同一流程迁移。

## 修订目标

- 建立项目级世界层级，而不是场景级临时层级。
- 让地形、地面物件、角色、拾取物、飞行物、高层遮挡使用统一规则。
- 保证 Player、Enemy、武器、道具、建筑、树木在不同场景中表现一致。
- 把临时 `z_index` 修补替换成可验证的结构和资源规则。

## 标准流程

### 1. 先判断对象类型

新增或迁移一个对象时，先归类：

- `TerrainLayer`：地板、草地、马路、河流、地面瓦块。
- `WorldActors`：玩家、敌人、地上可拾取物、掉落武器、树干、墙体主体、车辆、石块、草丛、尸体。
- `WorldEffects`：飞行中的子弹、斧子、枪口火光、命中特效、弹壳飞出表现。
- `HighOverlay`：树冠、屋顶、天花板、天空遮挡、高处装饰。
- `UI`：界面、按钮、血条、背包、调试 UI。

不能确定时，先按“是否需要和角色按脚底互相遮挡”判断：

- 需要：进入 `WorldActors`。
- 不需要，只是地面材质：进入 `TerrainLayer`。
- 永远覆盖角色：进入 `HighOverlay`。
- 短生命周期飞行/命中特效：进入 `WorldEffects`。

### 2. 再调整场景容器

正式场景推荐容器：

```text
SceneRoot
+-- TerrainLayer
+-- ShadowLayer
+-- WorldActors
+-- WorldEffects
+-- HighOverlay
+-- UI
```

规则：

- `WorldActors.y_sort_enabled = true`
- `TerrainLayer.z_index = RenderLayers.TERRAIN_Z`
- `ShadowLayer.z_index = RenderLayers.SHADOW_Z`
- `WorldActors.z_index = RenderLayers.WORLD_Y_SORT_Z`
- `WorldEffects.z_index = RenderLayers.WORLD_EFFECTS_Z`
- `HighOverlay.z_index = RenderLayers.HIGH_OVERLAY_Z`
- 新场景必须优先使用这些容器。

### 3. 再迁移可复用资源

角色和拾取物场景本身应保持项目级一致：

- Player 根节点：`z_index = RenderLayers.CHARACTER_ROOT_Z`
- Enemy 根节点：`z_index = RenderLayers.CHARACTER_ROOT_Z`
- Pickup 根节点：`z_index = RenderLayers.PICKUP_ROOT_Z`
- Player `Sprite` 身体层：保持 `0`
- Player `HandsSprite`：只允许在角色内部 `-1` 或 `0` 切换

这一步优先于单个地图微调，因为它会影响所有场景。

### 4. 最后处理场景特例

只有在标准结构无法表达时，才添加场景特例。场景特例必须写明：

- 为什么不能使用标准层级。
- 该特例影响哪些对象。
- 是否需要额外验证脚本。

临时修视觉的 `z_index` 不算合格特例。

## 当前状态

已完成：

- `docs/render-layer-guidelines.md` 定义了项目级规则。
- `scripts/render/render_layers.gd` 提供了统一层级常量。
- `navigation_obstacle_test_scene` 已作为当前主力样板场景，具备 `TerrainLayer`、`WorldActors`、`WorldEffects`、`HighOverlay`。
- Player、Big、Small、Axe、枪械拾取物、木棒拾取物和红色障碍主体已统一到 `WorldActors` 世界 YSort 基准层。

已移除，不再维护：

- `combat_test_scene`
- `myScene`
- `terrain_random_demo`
- `floor_only_random_map`

待补充：

- 真实树木、建筑、屋顶、天花板、高层遮挡还没有进入样板验证。

## 验证要求

迁移任何场景后至少运行：

- `tools/validate_render_layer_baseline.gd`
- 涉及 Player 手部/武器时运行 `tools/validate_player_layered_weapon_visual.gd`
- 涉及障碍测试样板时运行 `tools/validate_navigation_obstacle_test_scene.gd`

如果新增树木、建筑或屋顶，应追加专项验证，覆盖：

- 人物在树干上方和下方的遮挡。
- 树冠覆盖玩家、敌人、武器和飞行物。
- 屋顶/天花板覆盖整个角色，包括手部和武器。

## 复合物体迁移流程补充

复合物体使用“完整源资源 + 明确分层摆放 part”的流程。

- 完整源资源用于保留美术结构和后续生成参考。
- 分层摆放 part 才进入正式场景：阴影进入 `ShadowLayer`，树干/主体进入 `WorldActors`，树冠/屋顶进入 `HighOverlay`。
- `WorldActors` 中需要和角色互相遮挡的部分必须作为直接子节点参与 YSort。
- 不再允许复合物体通过自身脚本在编辑器或运行时偷偷移动子节点来修层级。
- 地图编辑时移动 `CompoundPropMarkers` 下的 marker；运行 `tools/build_compound_prop_layers.gd` 后生成或刷新正式层级节点。
