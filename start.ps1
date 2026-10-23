# 一键启动: Android 模拟器 + DeepSeek Harness(web) + 手机操作插件
# 用法: start.ps1 [-Avd <模拟器名>], 默认用 Android 14 的 dsh_api34
param([string]$Avd = 'dsh_api34')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$sdk  = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$avd  = $Avd

# 独立的 Harness 数据目录, 不影响 ~/.dsh
$env:DSH_HOME = Join-Path $root 'home'
# 让插件能直接找到 adb
$env:PATH = "$sdk\platform-tools;$env:PATH"

# 没有在线设备时启动模拟器
$online = adb devices | Select-String "`tdevice$"
if (-not $online) {
    Write-Host "启动模拟器 $avd ..."
    Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList "-avd $avd -no-snapshot-save -no-boot-anim"
    adb wait-for-device
    while ((adb shell getprop sys.boot_completed 2>$null) -ne '1') { Start-Sleep -Seconds 2 }
}
# 关闭动画, 否则 uiautomator dump 容易等不到界面空闲
foreach ($k in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
    adb shell settings put global $k 0
}
adb devices -l

Write-Host "启动 DeepSeek Harness Web 界面 ..."
& (Join-Path $root 'node_modules\.bin\dsh.cmd') --profile web
