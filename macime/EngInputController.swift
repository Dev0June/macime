//
//  EngInputController.swift
//  macime
//
//  Created by JBK on 2025/08/12.
//

import Foundation
import InputMethodKit
import ApplicationServices

@objc(EngInputController)
class EngInputController: IMKInputController {
    private let eventHandler = EventHandler()
    
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        
        // 접근성 권한 확인
        if !eventHandler.checkAccessibilityPermission() {
            print("접근성 권한이 필요합니다. 시스템 환경설정에서 권한을 허용해주세요.")
            _ = eventHandler.requestAccessibilityPermission()
        }
        
        let success = eventHandler.start()
        if success {
            print("활성화됨 - Half-QWERTY")
        } else {
            print("활성화 실패 - 접근성 권한을 확인하세요")
        }
    }
    
    override func deactivateServer(_ sender: Any!) {
        eventHandler.stop()
        super.deactivateServer(sender)
        print("EngInputController 비활성화됨")
    }
    
    override func inputText(_ string: String!, client: Any!) -> Bool {
        return false // CGEvent tap이 처리
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        return false // CGEvent tap이 처리
    }
}