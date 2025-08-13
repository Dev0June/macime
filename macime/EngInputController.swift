//
//  EngInputController.swift
//  macime
//
//  Created by JBK on 2025/08/12.
//

import Foundation
import InputMethodKit
import os.log

@objc(EngInputController)
class EngInputController: IMKInputController {  
    private var engContext: EngInputContext?
    private var client: IMKTextInput?
    private var spaceAutoReleaseTimer: Timer?
    private var spaceResetTimer: Timer?
    private var previousModifierFlags: NSEvent.ModifierFlags = []
    
    // 로깅용
    private let logger = OSLog(subsystem: "com.inputmethod.macime", category: "EngInputController")
    
    override func activateServer(_ sender: Any!) {
        print("=== EngInputController activateServer CALLED ===")
        print("Client: \(String(describing: sender))")
        
        super.activateServer(sender)
        client = sender as? IMKTextInput
        
        // EngInputContext 초기화 (표준 half-qwerty-wide 모드)
        engContext = EngInputContext(keyboardType: .halfQwertyWide)
        
        // 고급 기능 설정
        if let context = engContext {
            context.setSpaceTimeout(267)         // Space 타임아웃 267ms
        }
        
        print("EngInputController 활성화됨 - 표준 half-standard 모드 (고급 기능 활성화)")
        print("EngInputController client: \(client != nil ? "OK" : "NIL")")
        print("EngInputController engContext: \(engContext != nil ? "OK" : "NIL")")
    }
    
    override func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        
        // 타이머 정리
        spaceAutoReleaseTimer?.invalidate()
        spaceAutoReleaseTimer = nil
        spaceResetTimer?.invalidate()
        spaceResetTimer = nil
        
        engContext = nil
        print("EngInputController 비활성화됨")
    }
    
    override func inputText(_ string: String!, client: Any!) -> Bool {
        print("EngInputController inputText called: '\(string ?? "nil")'")
        
        guard let context = engContext else {
            print("EngInputController: 컨텍스트 없음")
            return false
        }
        
        guard let inputString = string, !inputString.isEmpty else {
            print("EngInputController inputText: empty string, returning false")
            return false
        }
        
        // 각 문자를 처리
        for char in inputString {
            let ascii = Int(char.asciiValue ?? 0)
            print("EngInputController: processing character '\(char)' (ascii: \(ascii))")
            
            _ = context.processKey(Int32(ascii))
            let preedit = context.preeditString()
            let commit = context.commitString()
            
            print("EngInputController: preedit='\(preedit)', commit='\(commit)'")
            
            // 결과를 클라이언트에 전송
            updateDisplay(client: client, preedit: preedit, committed: commit)
        }
        
        return true
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        print("EngInputController handle called: event type=\(event?.type.rawValue ?? 0), keyCode=\(event?.keyCode ?? 0)")
        
        guard let event = event else { 
            print("EngInputController handle: event is nil")
            return false 
        }
        
        // Space 키(49) 관련 모든 이벤트 로깅
        if event.keyCode == 49 {
            os_log("Space key event - type: %d, keyCode: %d, characters: '%{public}@'", 
                   log: logger, type: .default, event.type.rawValue, Int(event.keyCode), event.characters ?? "")
        }
        
        switch event.type {
        case .keyDown:
            print("EngInputController: keyDown event")
            return handleKeyDown(event: event, client: sender)
        case .keyUp:
            print("EngInputController: keyUp event")
            return handleKeyUp(event: event, client: sender)
        case .flagsChanged:
            print("EngInputController: flagsChanged event")
            return handleFlagsChanged(event: event, client: sender)
        default:
            print("EngInputController: other event type=\(event.type.rawValue)")
            return false
        }
    }
    
    private func handleKeyDown(event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        let characters = event.characters ?? ""
        
        print("EngInputController handleKeyDown: keyCode=\(keyCode), characters='\(characters)', modifiers=\(modifiers.rawValue)")
        
        guard let context = engContext else {
            print("EngInputController: eng context not initialized")
            return false
        }
        
        // 단축키 처리 (modifier 키가 눌린 경우)
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            print("EngInputController: Modifier key detected, delegating to system")
            // 조합 중인 텍스트가 있으면 완성 후 시스템으로 넘김
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            return false // 시스템이 단축키를 처리하도록 함
        }
        
        // 특수 키 처리
        switch keyCode {
        case 36: // Return
            print("EngInputController: Enter key pressed")
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            return false
            
        case 49: // Space Key Down - 연속 입력 지원
            os_log("Space key DOWN", log: logger, type: .default)
            
            // 이전 타이머가 실행 중이면 즉시 공백 commit하고 새로 시작
            if spaceAutoReleaseTimer != nil {
                spaceAutoReleaseTimer?.invalidate()
                spaceAutoReleaseTimer = nil
                // 이전 preedit을 공백으로 commit
                updateDisplay(client: client, preedit: "", committed: " ")
                os_log("Previous space committed (consecutive input)", log: logger, type: .default)
                // C 라이브러리 상태 리셋
                context.resetSpaceState()
            }
            
            // C 라이브러리 상태 설정 (Space+문자 조합용)
            let processed = context.processKeyDown(32)
            
            // 새로운 공백을 preedit으로 표시
            updateDisplay(client: client, preedit: " ", committed: "")
            os_log("Space shown as preedit", log: logger, type: .default)
            
            // 267ms 후 공백 commit (다른 키 조합 기다림)
            spaceAutoReleaseTimer = Timer.scheduledTimer(withTimeInterval: 0.267, repeats: false) { [weak self] _ in
                guard let self = self, let ctx = self.engContext else { return }
                
                // Space만 사용되고 다른 키 조합이 없었으면 공백 commit
                if ctx.isSpaceDown() && !ctx.isSpaceUsed() {
                    os_log("Space timeout - committing space", log: self.logger, type: .default)
                    self.updateDisplay(client: self.client, preedit: "", committed: " ")
                    ctx.resetSpaceState()
                }
                self.spaceAutoReleaseTimer = nil
            }
            
            return processed
            
        case 51: // Delete/Backspace - 영어 모드에서는 시스템이 처리
            print("EngInputController: Backspace key pressed - delegating to system")
            return false // 시스템이 backspace를 처리하도록 함
            
        case 53: // Escape
            print("EngInputController: Escape key pressed")
            let flush = context.flush()
            updateDisplay(client: client, preedit: "", committed: flush)
            return true
            
        default:
            // 일반 문자 처리 - 키 다운 이벤트로 처리
            if let char = characters.first {
                let ascii = Int(char.asciiValue ?? 0)
                os_log("Character key DOWN: '%{public}s' (ascii: %d)", log: logger, type: .default, String(char), ascii)
                os_log("Before keyDown - isSpaceDown: %{public}s", log: logger, type: .default, context.isSpaceDown() ? "TRUE" : "FALSE")
                
                let processed = context.processKeyDown(Int32(ascii))
                let preedit = context.preeditString()
                let commit = context.commitString()
                os_log("keyDown processed=%{public}s, preedit='%{public}s', commit='%{public}s'", log: logger, type: .default, processed ? "true" : "false", preedit, commit)
                os_log("After keyDown - isSpaceDown: %{public}s", log: logger, type: .default, context.isSpaceDown() ? "TRUE" : "FALSE")
                
                updateDisplay(client: client, preedit: preedit, committed: commit)
                
                // Space가 눌린 상태에서 다른 키가 오면 Space 타이머 취소
                if context.isSpaceDown() {
                    spaceAutoReleaseTimer?.invalidate()
                    spaceAutoReleaseTimer = nil
                    os_log("Space timer cancelled - character combo", log: logger, type: .default)
                }
                
                // Space+문자 조합 사용한 경우, 1초 후 Space 상태 리셋
                if context.isSpaceDown() && context.isSpaceUsed() {
                    spaceResetTimer?.invalidate()
                    spaceResetTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                        guard let self = self, let ctx = self.engContext else { return }
                        if ctx.isSpaceUsed() {
                            os_log("Auto-resetting space state after space+char usage", log: self.logger, type: .default)
                            ctx.resetSpaceState()
                        }
                        self.spaceResetTimer = nil
                    }
                }
                
                return processed
            }
        }
        
        return false
    }
    
    private func handleKeyUp(event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let characters = event.characters ?? ""
        
        print("EngInputController handleKeyUp: keyCode=\(keyCode), characters='\(characters)'")
        
        guard let context = engContext else {
            print("EngInputController: eng context not initialized")
            return false
        }
        
        // Space 키 업 처리
        if keyCode == 49 { // Space
            os_log("Space key UP", log: logger, type: .default)
            
            // 타이머 정리 (Space가 놓였으므로)
            spaceAutoReleaseTimer?.invalidate()
            spaceAutoReleaseTimer = nil
            
            // processKeyUp(32)에서 공백 출력 처리
            let processed = context.processKeyUp(32)
            let preedit = context.preeditString()
            let commit = context.commitString()
            
            os_log("Space UP processed=%{public}@, preedit='%{public}@', commit='%{public}@'", log: logger, type: .default, 
                   processed ? "true" : "false", preedit, commit)
            
            updateDisplay(client: client, preedit: preedit, committed: commit)
            return processed
        }
        
        return false
    }
    
    private func handleFlagsChanged(event: NSEvent, client: Any!) -> Bool {
        // 특별한 플래그 처리가 필요하면 여기에 추가
        return false
    }
    
    private func updateDisplay(client: Any!, preedit: String, committed: String) {
        guard let textClient = client as? any IMKTextInput else { return }
        
        // 완성된 텍스트 삽입
        if !committed.isEmpty {
            textClient.insertText(committed, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        
        // 조합 중인 텍스트 표시 또는 마킹 해제
        if !preedit.isEmpty {
            let attributes = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue]
            let attributedString = NSAttributedString(string: preedit, attributes: attributes)
            textClient.setMarkedText(attributedString, selectionRange: NSRange(location: 0, length: preedit.count), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        } else {
            // 조합이 끝났으면 마킹 해제
            textClient.setMarkedText(NSAttributedString(string: ""), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
    }
    
    // 조합 상태 표시
    override func updateComposition() {
        guard let context = engContext else { return }
        let preedit = context.preeditString()
        if !preedit.isEmpty {
            // 조합 중인 상태 표시
            if let textClient = client {
                let attributes = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue]
                let attributedString = NSAttributedString(string: preedit, attributes: attributes)
                textClient.setMarkedText(attributedString, selectionRange: NSRange(location: 0, length: preedit.count), replacementRange: NSRange(location: NSNotFound, length: 0))
            }
        }
    }
    
    // 조합 취소
    override func cancelComposition() {
        // 타이머 정리 (IME 전환 시 호출될 수 있음)
        spaceAutoReleaseTimer?.invalidate()
        spaceAutoReleaseTimer = nil
        spaceResetTimer?.invalidate()
        spaceResetTimer = nil
        
        guard let context = engContext else { return }
        let flush = context.flush()
        if let textClient = client {
            if !flush.isEmpty {
                textClient.insertText(flush, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            textClient.setMarkedText(NSAttributedString(), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
    
    // 추가 디버깅 메서드들
    override func commitComposition(_ sender: Any!) {
        // 타이머 정리 (IME 전환 시 호출될 수 있음)
        spaceAutoReleaseTimer?.invalidate()
        spaceAutoReleaseTimer = nil
        spaceResetTimer?.invalidate()
        spaceResetTimer = nil
        
        os_log("commitComposition called", log: logger, type: .default)
        super.commitComposition(sender)
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        os_log("candidates called", log: logger, type: .default)
        return super.candidates(sender)
    }
}