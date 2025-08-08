//
//  InputController.swift
//  macime
//
//  Created by JBK on 2025/07/06.
//

import Foundation
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    
    private var hangulContext: HangulInputContext?
    private var client: IMKTextInput?
    
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        client = sender as? IMKTextInput
        // 기본값: 한손 오른손 키보드
        // 나중에 설정에서 변경 가능하도록 할 키보드들:
        // - "1hand-right": 오른손 (기본값)  
        // - "1hand-left": 왼손
        hangulContext = HangulInputContext(keyboard: "1hand-right")
        print("macime 입력 컨트롤러가 활성화되었습니다.")
        print("macime client: \(client != nil ? "OK" : "NIL")")
        print("macime hangulContext: \(hangulContext != nil ? "OK" : "NIL")")
    }
    
    override func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        hangulContext = nil
        print("macime 입력 컨트롤러가 비활성화되었습니다.")
    }
    
    override func inputText(_ string: String!, client: Any!) -> Bool {
        print("macime inputText called: '\(string ?? "nil")'")
        
        guard let inputString = string, !inputString.isEmpty else {
            print("macime inputText: empty string, returning false")
            return false
        }
        
        guard let context = hangulContext else {
            print("macime inputText: hangul context not initialized")
            return false
        }
        
        // 각 문자를 처리
        for char in inputString {
            let ascii = Int(char.asciiValue ?? 0)
            print("macime inputText: processing character '\(char)' (ascii: \(ascii))")
            
            _ = context.processKey(Int32(ascii))
            let preedit = context.preeditString()
            let commit = context.commitString()
            
            print("macime inputText: preedit='\(preedit)', commit='\(commit)'")
            
            // 결과를 클라이언트에 전송
            updateDisplay(client: client, preedit: preedit, committed: commit)
        }
        
        return true
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        print("macime handle called: event type=\(event?.type.rawValue ?? 0)")
        
        guard let event = event else { 
            print("macime handle: event is nil")
            return false 
        }
        
        switch event.type {
        case .keyDown:
            print("macime handle: keyDown event")
            return handleKeyDown(event: event, client: sender)
        case .flagsChanged:
            print("macime handle: flagsChanged event")
            return handleFlagsChanged(event: event, client: sender)
        default:
            print("macime handle: other event type=\(event.type.rawValue)")
            return false
        }
    }
    
    private func handleKeyDown(event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        let characters = event.characters ?? ""
        
        print("macime handleKeyDown: keyCode=\(keyCode), characters='\(characters)', modifiers=\(modifiers.rawValue)")
        
        guard let context = hangulContext else {
            print("macime: hangul context not initialized")
            return false
        }
        
        // 단축키 처리 (modifier 키가 눌린 경우)
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            print("macime: Modifier key detected, delegating to system")
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
            print("macime: Enter key pressed")
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            // Enter 키는 시스템에서 직접 처리하도록 함
            return false
            
        case 49: // Space
            print("macime: Space key pressed")
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            updateDisplay(client: client, preedit: "", committed: " ")
            return true
            
        case 51: // Delete
            print("macime: Backspace key pressed")
            if context.isEmpty() {
                print("macime: No composition, delegating backspace to system")
                return false
            } else {
                let success = context.backspace()
                print("macime: backspace() returned: \(success)")
                let preedit = context.preeditString()
                let commit = context.commitString()
                print("macime: After backspace - preedit='\(preedit)', commit='\(commit)'")
                updateDisplay(client: client, preedit: preedit, committed: commit)
                return true
            }
            
        case 53: // Escape
            print("macime: Escape key pressed")
            let flush = context.flush()
            updateDisplay(client: client, preedit: "", committed: flush)
            return true
            
        default:
            // 일반 문자 처리 - 모든 키를 libhangul로 전달
            if let char = characters.first {
                let ascii = Int(char.asciiValue ?? 0)
                print("macime: Character key pressed: '\(char)' (ascii: \(ascii))")
                
                let processed = context.processKey(Int32(ascii))
                let preedit = context.preeditString()
                let commit = context.commitString()
                print("macime: processed=\(processed), preedit='\(preedit)', commit='\(commit)'")
                
                updateDisplay(client: client, preedit: preedit, committed: commit)
                return processed
            }
        }
        
        return false
    }
    
    private func handleFlagsChanged(event: NSEvent, client: Any!) -> Bool {
        // CapsLock 처리 등
        return false
    }
    
    private func updateDisplay(client: Any!, preedit: String, committed: String, backspace: Bool = false) {
        guard let textClient = client as? IMKTextInput else { return }
        
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
        guard let context = hangulContext else { return }
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
        guard let context = hangulContext else { return }
        let flush = context.flush()
        if let textClient = client {
            if !flush.isEmpty {
                textClient.insertText(flush, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            textClient.setMarkedText(NSAttributedString(), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
}
