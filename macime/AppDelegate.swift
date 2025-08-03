//
//  AppDelegate.swift
//  macime
//
//  Created by JBK
//

import Cocoa
import InputMethodKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var server = IMKServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("macime server started")
        
        // 재부팅 후 나오는 윈도우를 바로 끔
        if let w = NSApplication.shared.windows.first {
            w.close()
        }
    }
}