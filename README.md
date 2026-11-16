# 地牢远征 · Desktop Dungeons 复刻

> **字体说明**：`assets/fonts/` 下的中文子集字体提取自 macOS 系统字体，仅为本项目演示用。
> 若要商用或长期公开发布，请替换为开源中文字体（如 [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font)、[Zpix](https://github.com/SolidZORO/zpix-pixel-font)），
> 保持文件名 `ui_zh.ttf` / `ui_zh_bold.ttf` 即可自动生效，无需改代码。

单屏地牢 roguelike，致敬 [Desktop Dungeons](https://store.steampowered.com/app/226620/Desktop_Dungeons/)：
**探索即治疗、撞击即战斗、升级即满血**。10 个可玩关卡，3 个职业，中文界面。

- 引擎：Godot 4.7（GDScript）
- 画面：32px 像素素材，1280×720 原生分辨率（像素 1:1 不缩放）
- 素材：地砖 / 角色 / 怪物 / 道具由 PixelLab MCP 生成，音效与 BGM 由 `tools/gen_audio.py` 程序合成

## 运行

```bash
# 需要有 Godot 4.7+（brew install godot 或官网下载）
cd desktop-dungeons
godot --path .
```

首次运行会导入资源，耗时几秒。进度存档在 `user://progress.json`。

## 操作

| 按键 | 作用 |
|---|---|
| `WASD` / 方向键 | 移动；朝敌人移动即攻击 |
| `空格` / `.` | 原地待机一回合 |
| `Q` / `1` | 释放职业技能 |
| `E` / `2` | 使用第一个药水 |
| 鼠标 | 点击道具、技能、商店按钮 |
| `R` | 重开本关 |
| `Esc` | 返回标题 |

## 核心机制

1. **探索回血**：黑幕是唯一补给。每踏入一个未探索格，会揭示周围 3×3，并按新揭示格数回复生命与法力。地图剩余黑幕量 = 你的剩余资源。
2. **撞击战斗**：朝敌人移动即攻击，怪物在自己的回合攻击相邻的你。伤害 = 攻击 − 防御，几乎无随机，可以精确计算。
3. **升级回满**：击杀积累经验，升级瞬间满血满蓝并提升上限。卡着升级打强敌是核心技巧。
4. **难度梯度**：怪物按距离分三环带生成——近处杂兵、中距离中坚、远处精英；BOSS 在最深处。所以"先清弱的再推进"始终可行。

### 职业

| 职业 | 特点 | 技能 |
|---|---|---|
| 战士 | 血厚防高，每两次击杀永久 +1 攻击 | 猛击：1.8 倍伤害并打断目标 |
| 法师 | 血薄蓝多，火球无视线 | 火球术：3 格内造成 12+3×等级，无视一半防御 |
| 盗贼 | 高伤贪财 | 潜行：下次攻击 3 倍伤害并打断目标 |

### 十关

| 关 | 名称 | 主题 | BOSS |
|---|---|---|---|
| 1 | 鼠窟 | 教学 | 鼠王 |
| 2 | 哥布林营地 | 首次商店 | 哥布林酋长 |
| 3 | 骷髅墓穴 | 亡灵（物理抗性） | 骸骨领主 |
| 4 | 蛛网洞穴 | 中毒 | 蛛后 |
| 5 | 熔岩矿坑 | 再生 | 熔岩暴君 |
| 6 | 冰霜地窟 | 追击狼群 | 霜牙狼王 |
| 7 | 兽人要塞 | 高攻重甲 | 兽人督军 |
| 8 | 巫妖图书馆 | 吸血亡灵 | 巫妖 |
| 9 | 深渊裂隙 | 多特性混编 | 深渊领主 |
| 10 | 龙巢 | 终局综合 | 上古巨龙 |

击杀 BOSS 后会在其位置浮现阶梯，踏上即过关。

## 目录结构

```
desktop-dungeons/
├── project.godot
├── assets/            # 生成的像素素材、音频、字体子集
│   ├── tiles/         # 32px 地牢 Wang tileset
│   ├── chars/         # 玩家 3 职业 × 4 方向
│   ├── monsters/      # 15 种怪物
│   ├── items/         # 6 种道具图标
│   ├── audio/         # 程序合成音效 + 2 首 BGM
│   └── fonts/         # 中文子集字体（常规 + 粗体）
├── data/              # 全部数值，改这里不用动代码
│   ├── classes.json   # 职业
│   ├── monsters.json  # 怪物（含 tier 分层）
│   ├── items.json     # 道具
│   └── levels.json    # 10 关配置（怪物池、power、BOSS、配色）
├── scenes/Main.tscn
├── scripts/
│   ├── DB.gd              # 数据表加载（autoload）
│   ├── GameConfig.gd      # 常量、经验表、输入映射
│   ├── LevelGen.gd        # 洞穴生成 + 连通性校验
│   ├── DungeonState.gd    # 全部规则：探索、战斗、升级、商店
│   ├── Actor.gd           # 实体数据
│   ├── DungeonView.gd     # 地砖与迷雾渲染
│   ├── OverlayView.gd     # 血条、高亮、伤害飘字
│   ├── Hud.gd             # 全部自绘 UI
│   ├── Main.gd            # 界面状态机与输入
│   ├── Sfx.gd / Art.gd    # 音频与素材/字体入口
└── tools/
    ├── SmokeTest.tscn/.gd # 无头平衡测试
    └── gen_audio.py       # 音效与 BGM 合成脚本
```

## 调平衡

全部数值都在 `data/*.json`，改完直接运行即可：

- 玩家强弱：`classes.json` 的 `hp` / `atk` / `def` 与 `*_growth`
- 怪物强弱：`monsters.json` 的基础属性与 `traits`
- 关卡难度：`levels.json` 的 `power`（血量主缩放）、怪物数量与 BOSS 的 `hp_mul` / `atk_mul`
- 探索补给：`GameConfig.EXPLORE_CLAIRVOYANCE`（视野半径）与 `DungeonState._do_move` 里的回复公式

改完跑一遍平衡测试：

```bash
godot --headless tools/SmokeTest.tscn
```

它会用近似真人的策略把 10 关 × 3 职业各打 2 局，输出通关数与等级曲线。

## Web 导出

```bash
# 需要先安装 4.7.2 导出模板（编辑器：编辑器 → 管理导出模板）
godot --headless --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8000
```

`export_presets.cfg` 已放在项目里；模板缺失时导出会报错，装好模板即可。

## 素材与许可说明

- 地砖、角色、怪物、道具：PixelLab MCP 生成（本仓库内的使用权归项目作者）
- 音效与 BGM：`tools/gen_audio.py` 用标准库合成，无第三方素材
- 字体：`assets/fonts/ui_zh.ttf` 是从系统字体提取的**子集**（仅含本作用到的 729 个字符），仅用于本地/演示；
  若要公开发布，请替换为开源中文字体（如 Fusion Pixel、Zpix），只需要把文件放到 `assets/fonts/` 并保持文件名不变。
