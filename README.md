# 手机 Agent 部署说明（C:\phone）

DeepSeek Harness + dsh-mobile-gui-agent 手机插件 + Android 模拟器。
本文件记录 2026-10-21 至 10-22 期间改过的配置和插件版本，方便以后排查或回退。

## 日常使用

1. 双击 `start.cmd`：启动 Android 14 模拟器（没开时）、关闭动画、启动 Harness 并打开浏览器（http://127.0.0.1:3080）。
   - 换用 Android 16 模拟器：`pwsh -File start.ps1 -Avd medium_phone`
2. 在 Harness 里**新建会话**，直接在聊天里说要在手机上做什么，例如“帮我看看手机蓝牙开没开”。
   - 模型会调用 `phone_start_task`，说一句“开始操作手机”后结束这次回复，手机任务随即在同一个会话里启动。
   - 只有一台在线设备时自动使用它；多台时模型会问你用哪台。
   - 问原理、要操作说明、写代码时不会动手机。
   - 手机任务运行期间这个会话不能聊别的，要等任务结束或在面板里点“停止”。
3. 也可以用面板：先随便发一句话，切到 **mobile_gui_agent** 标签，选设备，在“任务”栏写任务，点“开始”。
4. 无论从哪里启动，进度和结果都显示在 mobile_gui_agent 面板（“Agent 步骤”最后一步来自 finish 的 message），对话里也能看到每一步。

## 版本一览

| 组件 | 版本 / 位置 | 说明 |
|---|---|---|
| DeepSeek Harness | `@deepseek-ai/dsh` **0.1.0-rc.8**（`package.json`） | 插件声明只兼容 0.1.x，不能直接升到 0.2.x |
| HMR 插件 | `@deepseek-ai/cordis-plugin-hmr` **1.0.17**（锁定） | rc.8 启动需要 `registerConfig`，1.0.18 起被删掉 |
| Timer 插件 | `@deepseek-ai/cordis-plugin-timer` 1.1.7 | rc.8 的依赖里漏装，手动补上 |
| 手机插件 | `dsh-mobile-gui-agent` **0.2.1-local.8** | 本地构建，见下文“插件源码” |
| 插件安装包 | `plugins\dsh-mobile-gui-agent-0.2.1-local.8.tgz` | profile 通过 `file:` 引用这个文件 |
| 聊天入口 | `chatEntry: deferred`（`phone_start_task`） | 阶段 A 原型 `executor` 已关闭，见下文 |
| 默认模型 | `deepseek-flash`（界面显示 DeepSeek-Flash） | 支持看图；旧会话仍是原来选的模型 |
| 模拟器 | `dsh_api34`：Android 14 google_apis x86_64 | `hw.gpu.mode=angle_indirect`，内存 4096 MB |
| 备用模拟器 | `medium_phone`：Android 16 | 原有，未改动 |

## 改过的配置文件

### `home\profiles\web\cordis.patch.yml`（Harness 配置补丁）

- **打开 HMR 服务**（`id: hmr`，`disabled: false`）：web 版默认关闭，但 rc.8 在 Windows 上启动必须有，否则报 “user patch-layer watching requires the Cordis HMR service”。
- **模型目录**（`id: llm-deepseek`）：内置目录只有 `deepseek-v4-flash`、`deepseek-v4-pro`，且都默认“只收文字”，插件因此不发截图。这里加入 `deepseek-flash` 并声明 `inputModalities: [text, image]`，原两个模型保留。
- **默认模型**（`id: agent-default-model`）：改为 `deepseek-flash`。
- **手机插件配置**（`id: mobile-gui-agent`）：照抄插件默认值，只多了 `agent.chatEntry`：
  - `deferred`（当前）：聊天用 `phone_start_task`，回复结束后在同一会话启动手机任务，面板同步显示。
  - `executor`（设计稿阶段 A 原型）：聊天用 `phone_run_task`，在子会话的执行 Agent 上跑任务，聊天等到结束后由主模型汇报结果；聊天的“停止”按钮能直接停掉执行 Agent。原型限制：高风险操作一律被拒绝（还没有把审批转到聊天）、等待期间看不到进度、子会话在界面上打不开。
  - 切换方法：改这一项后重启 Harness。

注意：这类补丁行是整行替换，不是合并；改 `llm-deepseek` 的 `models` 或 `mobile-gui-agent` 的配置时都要写出完整内容。

### `pnpm-workspace.yaml`（`C:\phone` 和 `home\profiles\web` 两处）

- `overrides`：把 `@deepseek-ai/cordis-plugin-hmr` 锁在 1.0.17。
- `allowBuilds`（仅 `C:\phone`）：允许 node-pty、koffi 等依赖运行安装脚本，否则 Harness 的终端等功能缺原生组件。

### `home\storages\workspace.json`

工作区路径为 `C:\phone\workspace`（从旧位置 `C:\Users\15821\dsh-phone` 搬来时改过）。

### `start.ps1` / `start.cmd`

- 默认启动 `dsh_api34`，可用 `-Avd` 换模拟器。
- 开机后把三项动画缩放设为 0：动画开着时 `uiautomator dump` 容易等不到界面空闲。
- 设置 `DSH_HOME=C:\phone\home`，Harness 数据独立于 `~/.dsh`（桌面版的数据不受影响）。

### 模拟器 `dsh_api34`（`%USERPROFILE%\.android\avd\dsh_api34.avd\config.ini`）

- `hw.gpu.mode=angle_indirect`（ANGLE 渲染）：默认渲染和 swiftshader 软件渲染都会开机循环（卡在 SurfaceFlinger）；`host` 能开机，但在这台 Intel Arc 显卡上模拟器窗口一直黑屏（手机本身正常，ADB 截图有画面）。ANGLE 既能开机，窗口也有画面。改之前的配置备份在同目录 `config.ini.bak`。
- `hw.ramSize=4096`。
- 窗口位置和大小在同目录的 `emulator-user.ini`：`window.x = 40`、`window.y = 40`、`window.scale = 0.300000`。手机是 1080×2400，窗口原尺寸比屏幕高，顶边会跑到屏幕外面，而模拟器窗口没有标题栏，拖不动；缩小后整个窗口都在屏幕内。觉得太小可以把 `window.scale` 调大，改完重启模拟器生效。

### `home\.agent-presets\whale\`（鲸鱼娘 Agent 预设）

- 在输入框上方的预设菜单里选「鲸鱼娘模式」即可，按会话选择；新会话默认仍是「标准模式」（`standard`）。
- `agent.cordis.yml` 是自带 `standard` 预设（dsh 0.1.0-rc.8）的原样拷贝，只改了开头的 `persona` 文本；`preset.yml` 是菜单里的名称、说明和排序（order 5）。
- 人设只管语气。文本里写明了优先级：工具规则、手机操作规则和 `finish` 优先，`finish` 的结果必须准确完整，代码、路径、数字保持原样。
- 预设必须自带 persona：`standard` 等预设的 persona 会盖掉部署级 persona，所以只改 `cordis.patch.yml` 里的 persona 对网页会话不生效。
- 修改后不用重启 Harness，下次打开预设菜单就会重新读取。
- 已测：鲸鱼娘模式下普通聊天是鲸鱼娘口吻；同一会话里的手机任务（查看蓝牙开关）照常调用 `finish`，结果准确，而且人设仍在系统提示词里。

## 插件源码

- 仓库：`C:\dsh-mobile-gui-agent`，基于上游 v0.2.1（提交 `7a77944`）
- 分支：`fix/observation-fallback-timeouts`（只在本地，未推送）
  - `c2b4d4c` fix(build): Windows 上通过 shell 调用 tsc（Node 24 下原构建脚本直接报错）
  - `00f387b` fix: 界面结构读不到时继续观察，具体包括：
    - 遇到 “could not get idle state” 或读取超时，立即放弃，不再换方式读、不再重试，并 `pkill -x uiautomator` 清掉手机上卡住的进程
    - 读不到界面结构时仍返回截图和当前应用信息，并标注“界面结构不可用”，不再把点击前的画面当结果
    - 失败后的补救观察有时限
    - 截图超过附件上限（每边 2000 像素）时先缩小，并告诉模型缩放比例
    - 要求答案写进 finish；模型只在对话里回答时提醒一次，用户取消仍会立即停止
- 分支：`feat/chat-start-phone-task`（基于上面的修复分支，只在本地，未推送）
  - `c2a69bd` feat: 聊天里一句话启动手机任务（`phone_start_task`，回复结束后启动）
  - `8a446c2` feat: 阶段 A 原型，子会话执行 Agent（`phone_run_task`，`chatEntry: executor` 才启用），新增依赖 `@deepseek-ai/dsh-subagent`
- 测试：`pnpm run check`（类型检查、构建、128 个测试、打包校验）
- 重新打包安装：
  1. 在源码仓库改 `package.json` 版本号，运行 `pnpm pack --pack-destination C:\phone\plugins`
  2. 先停掉 Harness，再在 `C:\phone` 运行（`DSH_HOME` 设为 `C:\phone\home`）：
     `node_modules\.bin\dsh.cmd plugin --profile web add ./plugins/<新包名>.tgz`

## 回退

- **换回旧的本地插件**：用上面的 `plugin add` 命令装 `plugins` 里的 `local.1` 或 `local.2`。
  - local.1：只有观察兜底和超时修复
  - local.2：再加截图缩放
  - local.3：再加 finish 收尾提醒（没有聊天启动工具）
  - local.4：再加聊天里一句话启动（`phone_start_task`）
  - local.6：再加阶段 A 原型（默认关闭，`chatEntry: executor` 才启用）。local.5 是它的中间版本，用户停止后模型会重跑任务，已删除
  - local.8：手机任务每步动作前说一句进度；finish 后在聊天里用一两句话复述结果（只复述 finish 内容，不加推断）。local.7 是中间版本，总结会加上屏幕上没有的信息（猜上午/下午、说在充电）
- **换回上游原版插件**：`plugins\profile-package.json.before` 是第一次装本地插件前的 profile `package.json`（引用 GitHub 上游提交 `7a77944`），用它覆盖 `home\profiles\web\package.json` 后，在该目录运行 `pnpm install`。
- **不让模型看图**：删掉 `cordis.patch.yml` 里 `llm-deepseek` 和 `agent-default-model` 两段，重启 Harness。

## 已知问题

- **会话不能跨文件夹迁移**：会话日志里写死了路径。搬家前的两条测试会话备份在 `old-sessions\`，Harness 已不再读取。
- **“关于手机”这类一直重画的页面**：读不到界面结构，只能靠截图；每次读取要等满 10 秒超时。
- **token 消耗**：每一步都附带截图，步数一多输入 token 增长很快（13 步的任务约 29.5 万）。
- **中文输入**：没装 ADBKeyboard，Agent 只能输入英文。
- **Harness 版本**：锁在 0.1.0-rc.8。插件不兼容 0.2.x，升级前要先适配插件。
- **Harness 服务的生命周期**：从 Claude 会话里启动的 Harness 会随会话关闭而停止；平时用 `start.cmd` 启动。

## 本机其他相关改动

- 全局安装了 `@deepseek-ai/dsh` 0.2.1-rc.2 和 `pnpm`，本部署不用它们。不需要的话可以卸载：`npm uninstall -g @deepseek-ai/dsh`
- Android SDK 新增了 `cmdline-tools\latest` 和 Android 14 镜像 `system-images\android-34\google_apis\x86_64`（约 4.2 GB）。
- 旧部署目录 `C:\Users\15821\dsh-phone` 仍在，确认无用后可以删除。
