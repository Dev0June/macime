//
//  InputController.swift
//  macime
//
//  HangulKit 기반 한글 입력 컨트롤러
//  갈마들이 키보드 지원 (1hand-right, 1hand-left)
//

import InputMethodKit

@objc(MacimeInputController)
open class MacimeInputController: IMKInputController {
    
    private var hangulContext: _HangulInputContext?
    private var currentKeyboard = "1hand-right" // 기본값: 오른손 갈마들이
    
    override open func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        NSLog("macime activated with HangulKit")
        
        // HangulKit 컨텍스트 초기화
        hangulContext = _HangulInputContext(keyboard: currentKeyboard)
        
        if hangulContext == nil {
            NSLog("Failed to initialize HangulInputContext with keyboard: \(currentKeyboard)")
        } else {
            NSLog("HangulInputContext initialized successfully with keyboard: \(currentKeyboard)")
        }
    }
    
    override open func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        NSLog("macime deactivated")
        
        // 남은 조합 완료
        commitComposition(sender)
        
        // 컨텍스트 정리
        hangulContext = nil
    }
    
    override open func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else {
            return false
        }
        
        guard let context = hangulContext else {
            NSLog("HangulInputContext is nil")
            return false
        }
        
        let keyCode = event.keyCode
        
        // 특수 키 처리
        if keyCode == 36 || keyCode == 49 { // Enter or Space
            commitComposition(sender)
            return false
        }
        
        if keyCode == 51 { // Backspace
            if context.backspace() {
                updateDisplay(client: sender)
                return true
            } else {
                return false // 더 이상 지울 것이 없으면 시스템에 위임
            }
        }
        
        // 키보드 전환 (Cmd + Space)
        if event.modifierFlags.contains(.command) && keyCode == 49 {
            switchKeyboard()
            return true
        }
        
        // ASCII 키 입력 처리
        if let characters = event.characters, !characters.isEmpty {
            let firstChar = characters.first!
            let ascii = Int32(firstChar.asciiValue ?? 0)
            
            if ascii > 0 {
                let processed = context.processKey(ascii)
                if processed {
                    updateDisplay(client: sender)
                    return true
                }
            }
        }
        
        return false
    }
    
    private func updateDisplay(client sender: Any!) {
        guard let context = hangulContext,
              let client = sender as? IMKTextInput else { return }
        
        let commit = context.commitString()
        let preedit = context.preeditString()
        
        // 완성된 문자가 있으면 입력
        if !commit.isEmpty {
            client.insertText(commit, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        
        // 조합 중인 문자 표시
        if !preedit.isEmpty {
            client.setMarkedText(preedit, 
                               selectionRange: NSRange(location: preedit.count, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            client.setMarkedText("", 
                               selectionRange: NSRange(location: 0, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
    
    override open func commitComposition(_ sender: Any!) {
        guard let context = hangulContext,
              let client = sender as? IMKTextInput else { return }
        
        // 남은 조합 강제 완료
        let flushed = context.flush()
        if !flushed.isEmpty {
            client.insertText(flushed, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        
        // 마킹된 텍스트 제거
        client.setMarkedText("", 
                           selectionRange: NSRange(location: 0, length: 0),
                           replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    
    // MARK: - 키보드 전환 기능
    
    private func switchKeyboard() {
        // 오른손 ↔ 왼손 갈마들이 전환
        currentKeyboard = (currentKeyboard == "1hand-right") ? "1hand-left" : "1hand-right"
        
        // 현재 조합 완료
        if let context = hangulContext {
            let flushed = context.flush()
            if !flushed.isEmpty {
                // 마지막 클라이언트에 입력 (실제로는 현재 포커스된 앱)
                // 여기서는 로그만 출력
                NSLog("Switching keyboard - flushed text: \(flushed)")
            }
        }
        
        // 새 키보드로 컨텍스트 재생성
        hangulContext = _HangulInputContext(keyboard: currentKeyboard)
        
        NSLog("Keyboard switched to: \(currentKeyboard)")
        
        // 사용자에게 알림 (간단한 방법)
        let notification = "\(currentKeyboard == "1hand-right" ? "오른손" : "왼손") 갈마들이"
        NSLog("Active keyboard: \(notification)")
    }
    
    // MARK: - 상태 확인 메서드
    
    override open func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        // 필요시 추가 설정 처리
        super.setValue(value, forTag: tag, client: sender)
    }
}