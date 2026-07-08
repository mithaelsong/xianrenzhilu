//
//  AppDelegate.swift
//  仙人指路 2 测试
//
//  Created by 宋晓筱 on 2026/6/20.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 启动阶段 UI 主窗口创建前可能短暂无窗口；禁止 AppKit 自动终止抢跑。
        ProcessInfo.processInfo.disableAutomaticTermination("正在启动仙人指路 UI 主窗口")
        NSApp.setActivationPolicy(.regular)

        Task {
            await KJXRZApplication.shared.start()
            ProcessInfo.processInfo.enableAutomaticTermination("仙人指路 UI 主窗口启动完成")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        KJXRZApplication.shared.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

