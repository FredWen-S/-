# 手机 Agent 部署说明（C:\phone）

DeepSeek Harness + dsh-mobile-gui-agent 手机插件 + Android 模拟器。
本文件记录 2026-10-21 至 10-22 期间改过的配置和插件版本，方便以后排查或回退。

## 日常使用

1. 双击 `start.cmd`：启动 Android 14 模拟器（没开时）、关闭动画、启动 Harness 并打开浏览器（http://127.0.0.1:3080）。
   - 换用 Android 16 模拟器：`pwsh -File start.ps1 -Avd medium_phone`
2. 在 Harness 里**新建会话**，先随便发一句话（插件要求先有一轮对话，手机面板才会出现）。
3. 切到 **mobile_gui_agent** 标签，选设备，在“任务”栏写任务，点“开始”。
4. 结果显示在面板顶部和“Agent 步骤”最后一步（来自 finish 的 message）。

## 版本一览

| 组件 | 版本 / 位置 | 说明 |
|---|---|---|
| DeepSeek Harness | `@deepseek-ai/dsh` **0.1.0-rc.8**（`package.json`） | 插件声明只兼容 0.1.x，不能直接升到 0.2.x |
| HMR 插件 | `@deepseek-ai/cordis-plugin-hmr` **1.0.17**（锁定） | rc.8 启动需要 `registerConfig`，1.0.18 起被删掉 |
| Timer 插件 | `@deepseek-ai/cordis-plugin-timer` 1.1.7 | rc.8 的依赖里漏装，手动补上 |
| 手机插件 | `dsh-mobile-gui-agent` **0.2.1-local.3** | 本地构建，见下文“插件源码” |
| 插件安装包 | `plugins\dsh-mobile-gui-agent-0.2.1-local.3.tgz` | profile 通过 `file:` 引用这个文件 |
| 默认模型 | `deepseek-flash`（界面显示 DeepSeek-Flash） | 支持看图；旧会话仍是原来选的模型 |
| 模拟器 | `dsh_api34`：Android 14 google_apis x86_64 | `hw.gpu.mode=host`，内存 4096 MB |
| 备用模拟器 | `medium_phone`：Android 16 | 原有，未改动 |

## 改过的配置文件

### `home\profiles\web\cordis.patch.yml`（Harness 配置补丁）

- **打开 HMR 服务**（`id: hmr`，`disabled: false`）：web 版默认关闭，但 rc.8 在 Windows 上启动必须有，否则报 “user patch-layer watching requires the Cordis HMR service”。
- **模型目录**（`id: llm-deepseek`）：内置目录只有 `deepseek-v4-flash`、`deepseek-v4-pro`，且都默认“只收文字”，插件因此不发截图。这里加入 `deepseek-flash` 并声明 `inputModalities: [text, image]`，原两个模型保留。
- **默认模型**（`id: agent-default-model`）：改为 `deepseek-flash`。

注意：这类补丁行是整行替换，不是合并；改 `llm-deepseek` 的 `models` 时要写出完整列表。

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

- `hw.gpu.mode=host`：默认渲染和 swiftshader 软件渲染都会开机循环（卡在 SurfaceFlinger），用宿主机显卡才能开机。
- `hw.ramSize=4096`。

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
- 测试：`pnpm run check`（类型检查、构建、123 个测试、打包校验）
- 重新打包安装：
  1. 在源码仓库改 `package.json` 版本号，运行 `pnpm pack --pack-destination C:\phone\plugins`
  2. 先停掉 Harness，再在 `C:\phone` 运行（`DSH_HOME` 设为 `C:\phone\home`）：
     `node_modules\.bin\dsh.cmd plugin --profile web add ./plugins/<新包名>.tgz`

## 回退

- **换回旧的本地插件**：用上面的 `plugin add` 命令装 `plugins` 里的 `local.1` 或 `local.2`。
  - local.1：只有观察兜底和超时修复
  - local.2：再加截图缩放
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
