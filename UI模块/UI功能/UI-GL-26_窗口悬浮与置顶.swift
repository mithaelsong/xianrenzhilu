// 功能11A: 窗口悬浮与置顶
// 对应: 窗口层级控制（z-order），浮动窗口、置顶、普通层级切换
// 优先级: P0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "11A_窗口悬浮与置顶")

// 类型定义已迁移至 UI-GL-26_types.swift

// MARK: - 测试
internal func test_UI11A() {
    print("\n=== UI-11A 窗口层级管理测试 ===\n")
    
    let manager = UIWindowLevelManager.shared
    
    // 测试层级设置
    manager.setLevel(windowID: "test-1", level: .floating)
    assert(manager.getLevel(windowID: "test-1") == .floating)
    
    manager.setLevel(windowID: "test-1", level: .normal)
    assert(manager.getLevel(windowID: "test-1") == .normal)
    
    print("✅ 测试通过: 层级管理功能正常")
}
