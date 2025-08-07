//
//  macimeApp.swift
//  macime
//
//  Created by JBK on 2025/07/06.
//

import SwiftUI

@main
struct macimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}