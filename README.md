# 喝水提醒 · Water Reminder

一个用 Swift、AppKit 和 SwiftUI 编写的 macOS 菜单栏小工具，每隔 30 分钟用全屏提醒你喝水。

## 功能

- 菜单栏显示倒计时，控制面板可查看状态。
- 到点在所有连接的屏幕上显示全屏提醒。
- 点击「我喝水了」或按 Enter / Esc 关闭提醒，重新计时 30 分钟。
- 支持延后 10 分钟、暂停、继续和重新计时。
- 关闭控制面板后继续在后台运行；菜单栏中可退出应用。
- 睡眠时不唤醒电脑，唤醒后补发到期提醒，不堆积提醒窗口。
- 无需联网，无第三方依赖，不收集数据。

## 从源码运行

需要 macOS 和可用的 Xcode / Swift 命令行工具。本项目在 Apple Silicon Mac 上构建使用；脚本默认构建当前 Mac 的架构。

```sh
git clone https://github.com/chenyuxiaojin/water-reminder-macos.git
cd water-reminder-macos
./build.sh
open 喝水提醒.app
```

构建脚本生成 `喝水提醒.app`，进行本地签名，并执行内置的 12 项计时状态检查。应用产物不纳入 Git 版本控制。

可以将生成的应用拖到「应用程序」文件夹。默认不会开机启动，退出应用或重启电脑后需重新打开。

## 文件

- `Sources/WaterReminder.swift`：界面、计时逻辑和内置状态检查。
- `build.sh`：构建与本地签名脚本。
- [使用说明](使用说明.md)：操作方式和手动测试入口。
