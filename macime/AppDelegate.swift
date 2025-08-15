//
//  AppDelegate.swift
//  macime
//
//  Created by JBK on 2025/07/06.
//

import Foundation
import InputMethodKit
import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate { 
    var server: IMKServer?
    private let logger = OSLog(subsystem: "com.inputmethod.macime", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 접근성 권한 확인 (앱 시작 시 한 번만)
        checkAccessibilityPermission()
        
        // InputMethodKit 서버 초기화
        let connectionName = "macime_Connection"
        let bundleIdentifier = "com.inputmethod.macime"
        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
        
        // 입력 메서드 등록
        registerInputMethod()

        if let w = NSApplication.shared.windows.first {
            w.close()
        }
    }
    
    func registerInputMethod() {
        // 입력 메서드 등록 로직
        os_log("macime 입력 메서드가 등록되었습니다.", log: logger, type: .info)
    }
    
    // 접근성 권한 확인 (설치 직후 무조건 팝업 표시)
    private func checkAccessibilityPermission() {
        // 무조건 권한 요청 팝업 표시
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        if hasPermission {
            os_log("접근성 권한이 허용되었습니다", log: logger, type: .info)
        } else {
            os_log("접근성 권한이 거부되었거나 아직 설정되지 않았습니다", log: logger, type: .error)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 앱 종료 시 정리 작업
        os_log("macime 입력 메서드가 종료됩니다.", log: logger, type: .info)
    }
}
