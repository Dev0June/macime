//
//  InputController.swift
//  macime
//
//  Created by JBK on 2025/07/06.
//

import Foundation
import InputMethodKit
import ApplicationServices
import CoreGraphics
import Carbon.HIToolbox
import os.log

@objc(InputController)
class InputController: IMKInputController {
    
    private var hangulContext: HangulInputContext?
    private var client: IMKTextInput?
    
    // 영문 모드용 이벤트 핸들러
    private let eventHandler = EventHandler()
    
    // 로거
    private let logger = OSLog(subsystem: "com.inputmethod.macime", category: "InputController")
    
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        client = sender as? IMKTextInput
        
        // 현재 입력 소스 정보 상세 출력
        if let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            os_log("=== Current Input Source Debug ===", log: logger, type: .info)
            
            // 입력 소스 ID 확인
            if let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let sourceID = Unmanaged<CFString>.fromOpaque(sourceIDRef).takeUnretainedValue() as String
                os_log("TISInputSourceID: %@", log: logger, type: .info, sourceID)
                
                if sourceID == "com.inputmethod.macime.korean" {
                    os_log("설정: 한글 모드", log: logger, type: .info)
                    setupKoreanMode()
                } else if sourceID == "com.inputmethod.macime.english" {
                    os_log("설정: 영문 모드", log: logger, type: .info)
                    setupEnglishMode()
                } else {
                    os_log("알 수 없는 TISInputSourceID, 기본값: 한글 모드", log: logger, type: .info)
                    setupKoreanMode()
                }
            } else {
                os_log("TISInputSourceID를 가져올 수 없음, 기본값: 한글 모드", log: logger, type: .info)
                setupKoreanMode()
            }
            
            // 추가 디버깅 정보
            if let bundleIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyBundleID) {
                let bundleID = Unmanaged<CFString>.fromOpaque(bundleIDRef).takeUnretainedValue() as String
                os_log("Bundle ID: %@", log: logger, type: .info, bundleID)
            }
            
            if let nameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                let name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
                os_log("Localized Name: %@", log: logger, type: .info, name)
            }
            
            os_log("================================", log: logger, type: .info)
        } else {
            os_log("현재 입력 소스를 가져올 수 없음, 기본값: 한글 모드", log: logger, type: .info)
            setupKoreanMode()
        }

        os_log("macime 입력 컨트롤러 활성화: %@ 모드", log: logger, type: .info, hangulContext != nil ? "한글" : "영문")
        os_log("macime client: %@", log: logger, type: .info, client != nil ? "OK" : "NIL")
    }
    
    override func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        
        if hangulContext != nil {
            hangulContext = nil
        } else {
            eventHandler.stop()
        }
        
        print("macime 입력 컨트롤러 비활성화: \(hangulContext != nil ? "한글" : "영문") 모드")
    }
    
    private func setupKoreanMode() {
        os_log("=== 한글 모드 설정 시작 ===", log: logger, type: .info)
        
        // 기존 EventHandler 정지 (영문 모드에서 전환 시)
        eventHandler.stop()
        os_log("EventHandler 정지 완료", log: logger, type: .info)
        
        // 한글 컨텍스트 초기화
        hangulContext = HangulInputContext(keyboard: "1hand-right")
        os_log("한글 컨텍스트 초기화: %@", log: logger, type: .info, hangulContext != nil ? "성공" : "실패")
        
        os_log("=== 한글 모드 설정 완료 ===", log: logger, type: .info)
    }
    
    private func setupEnglishMode() {
        os_log("=== 영문 모드 설정 시작 ===", log: logger, type: .info)
        
        // 한글 컨텍스트 해제
        hangulContext = nil
        os_log("한글 컨텍스트 해제 완료", log: logger, type: .info)
        
        // 접근성 권한 확인
        if !eventHandler.checkAccessibilityPermission() {
            os_log("접근성 권한이 필요합니다", log: logger, type: .error)
            _ = eventHandler.requestAccessibilityPermission()
        }
        
        let success = eventHandler.start()
        if success {
            os_log("EventHandler 시작 성공 - Half-QWERTY 활성화", log: logger, type: .info)
        } else {
            os_log("EventHandler 시작 실패 - 접근성 권한 확인 필요", log: logger, type: .error)
        }
        
        os_log("=== 영문 모드 설정 완료 ===", log: logger, type: .info)
    }
    
    override func inputText(_ string: String!, client: Any!) -> Bool {
        os_log("inputText called: '%@'", log: logger, type: .info, string ?? "nil")
        
        // 영문 모드에서는 시스템 기본 처리
        guard let context = hangulContext else {
            os_log("영문 모드 - 시스템 기본 처리", log: logger, type: .info)
            return false  // 시스템이 처리하도록 함
        }
        
        // 한글 모드 처리
        guard let inputString = string, !inputString.isEmpty else {
            print("macime inputText: empty string, returning false")
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
        
        // 영문 모드에서는 CGEvent tap이 처리
        guard hangulContext != nil else {
            return false
        }
        
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
        // 영문 모드에서는 조합이 없음
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
        // 영문 모드에서는 조합이 없음
        guard let context = hangulContext else { return }
        let flush = context.flush()
        if let textClient = client {
            if !flush.isEmpty {
                textClient.insertText(flush, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            textClient.setMarkedText(NSAttributedString(), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
    
    // 입력 모드가 변경될 때 호출
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        os_log("=== setValue called ===", log: logger, type: .info)
        os_log("tag: %d, value: %@", log: logger, type: .info, tag, String(describing: value))
        
        // setValue의 value 파라미터에서 직접 TISInputSourceID 확인
        if let sourceID = value as? String {
            os_log("setValue - Direct TISInputSourceID: %@", log: logger, type: .info, sourceID)
            
            if sourceID == "com.inputmethod.macime.korean" && hangulContext == nil {
                os_log("setValue - 한글 모드로 전환", log: logger, type: .info)
                setupKoreanMode()
            } else if sourceID == "com.inputmethod.macime.english" && hangulContext != nil {
                os_log("setValue - 영문 모드로 전환", log: logger, type: .info)
                setupEnglishMode()
            }
        }
        
        super.setValue(value, forTag: tag, client: sender)
    }
    
    // 입력 모드 변경 시점 감지를 위한 추가 메서드
    override func recognizedEvents(_ sender: Any!) -> Int {
        os_log("recognizedEvents called", log: logger, type: .debug)
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }
}
