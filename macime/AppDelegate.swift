//
//  AppDelegate.swift
//  macime
//
//  Created by JBK on 2025/07/06.
//

import Foundation
import InputMethodKit
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var server: IMKServer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        print("macime 입력 메서드가 등록되었습니다.")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 앱 종료 시 정리 작업
        print("macime 입력 메서드가 종료됩니다.")
    }
}
