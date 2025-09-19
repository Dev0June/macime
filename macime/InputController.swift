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
    private let logger = OSLog(subsystem: "com.inputmethod.macime", category: "InputController")
    
    // 영문 모드용 이벤트 핸들러
    private let eventHandler = EventHandler()
    
    // Caps Lock 토글 상태 추적
    private var isCapsLockOn = false
    
    // ============================================================================
    // Info.plist에서 입력 모드 매핑 읽어오기  
    private lazy var inputModeMapping: [String: (id: String, language: String)] = {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let componentDict = infoDictionary["ComponentInputModeDict"] as? [String: Any],
              let modeListDict = componentDict["tsInputModeListKey"] as? [String: Any] else {
            return [:]
        }
        
        var mapping: [String: (id: String, language: String)] = [:]
        for (displayName, modeInfo) in modeListDict {
            if let modeDict = modeInfo as? [String: Any],
               let sourceID = modeDict["TISInputSourceID"] as? String,
               let language = modeDict["TISIntendedLanguage"] as? String {
                let modeInfo = (id: sourceID, language: language)
                mapping[displayName] = modeInfo
                mapping[sourceID] = modeInfo // ID로도 매핑
            }
        }
        
        return mapping
    }()
    
    // 입력 모드가 변경될 때 호출
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        if let sourceID = value as? String,
           let modeInfo = inputModeMapping[sourceID] {
            let switchingFromKorean = hangulContext != nil && modeInfo.language != "ko"

            if switchingFromKorean {
                forceCommitCurrentState()
            }

            if modeInfo.language == "ko" {
                if hangulContext == nil {
                    setupKoreanMode()
                }
            } else if modeInfo.language == "en" {
                setupEnglishMode()
            } else if switchingFromKorean {
                // 확실하게 마킹된 텍스트 해제 후 기본 한글 모드 복귀
                setupKoreanMode()
            }
        }

        super.setValue(value, forTag: tag, client: sender)
    }
    // ============================================================================


    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        client = sender as? IMKTextInput
        
        // 이전 세션의 상태 완전 초기화
        cleanupPreviousState()
        
        // 현재 입력 소스에 따라 모드 설정
        if let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
            let sourceID = Unmanaged<CFString>.fromOpaque(sourceIDRef).takeUnretainedValue() as String
            
            if let modeInfo = inputModeMapping[sourceID] {
                if modeInfo.language == "ko" {
                    setupKoreanMode()
                } else if modeInfo.language == "en" {
                    setupEnglishMode()
                } else {
                    setupKoreanMode() // 기본값
                }
            } else {
                setupKoreanMode() // 기본값
            }
        } else {
            setupKoreanMode() // 기본값
        }

        os_log("macime 활성화: %@ 모드 (상태 초기화 완료)", log: logger, type: .info, hangulContext != nil ? "한글" : "영문")
    }
    
    override func deactivateServer(_ sender: Any!) {
        // 상태 전환 전에 현재 조합/입력 상태 강제 정리
        forceCommitCurrentState()
        
        super.deactivateServer(sender)
        
        // 모든 상태 완전 초기화
        cleanupPreviousState()
        
        os_log("macime 비활성화 (상태 정리 완료)", log: logger, type: .info)
    }
    
    private func setupKoreanMode() {
        eventHandler.stop()
        hangulContext = HangulInputContext(keyboard: "1hand-right")
        os_log("한글 모드 설정", log: logger, type: .info)
    }
    
    private func setupEnglishMode() {
        hangulContext = nil
        let success = eventHandler.start()
        if !success {
            os_log("EventHandler 시작 실패 - 접근성 권한 필요", log: logger, type: .error)
        }
        os_log("영문 모드 설정", log: logger, type: .info)
    }
    
    // 이전 세션의 상태 완전 초기화
    private func cleanupPreviousState() {
        // 한글 컨텍스트 초기화
        if let context = hangulContext {
            let _ = context.flush() // 버퍼 비우기
            hangulContext = nil
        }
        
        // 영문 이벤트 핸들러 정리
        eventHandler.stop()

        // Caps Lock 상태 초기화
        isCapsLockOn = false
        
        // 클라이언트의 마킹 상태 초기화
        if let textClient = client {
            textClient.setMarkedText(NSAttributedString(), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        
        os_log("이전 세션 상태 완전 초기화", log: logger, type: .debug)
    }
    
    // 현재 조합/입력 상태 강제 커밋
    private func forceCommitCurrentState() {
        // 한글 조합 중인 경우 강제 완성
        if let context = hangulContext, let textClient = client {
            let flush = context.flush()
            if !flush.isEmpty {
                // 마킹된 텍스트를 완성된 텍스트로 교체
                textClient.insertText(flush, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                os_log("한글 조합 상태 강제 커밋: %@", log: logger, type: .debug, flush)
            } else {
                // 조합 중인 텍스트가 없으면 마킹만 해제
                textClient.setMarkedText(NSAttributedString(), selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
            }
        }
        
        os_log("현재 입력 상태 강제 커밋 완료", log: logger, type: .debug)
    }
    
    override func inputText(_ string: String!, client: Any!) -> Bool {
        // 영문 모드에서는 시스템 기본 처리
        guard let context = hangulContext else {
            return false
        }
        
        guard let inputString = string, !inputString.isEmpty else {
            return false
        }
        
        // 각 문자를 처리
        for char in inputString {
            let ascii = Int(char.asciiValue ?? 0)
            _ = context.processKey(Int32(ascii))
            let preedit = context.preeditString()
            let commit = context.commitString()
            updateDisplay(client: client, preedit: preedit, committed: commit)
        }
        
        return true
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // 영문 모드에서는 CGEvent tap이 처리
        guard hangulContext != nil else {
            return false
        }
        
        guard let event = event else { 
            return false 
        }
        
        switch event.type {
        case .keyDown:
            return handleKeyDown(event: event, client: sender)
        case .flagsChanged:
            return handleFlagsChanged(event: event, client: sender)
        default:
            return false
        }
    }
    
    private func handleKeyDown(event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        let characters = event.characters ?? ""
        
        guard let context = hangulContext else {
            return false
        }
        
        // 단축키 처리 (modifier 키가 눌린 경우)
        if modifiers.contains(.command) || 
           modifiers.contains(.control) || 
           modifiers.contains(.option) {
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
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            return false
            
        case 49: // Space
            let flush = context.flush()
            if !flush.isEmpty {
                updateDisplay(client: client, preedit: "", committed: flush)
            }
            updateDisplay(client: client, preedit: "", committed: " ")
            return true
            
        case 51: // Delete
            if context.isEmpty() {
                return false
            } else {
                _ = context.backspace()
                let preedit = context.preeditString()
                let commit = context.commitString()
                updateDisplay(client: client, preedit: preedit, committed: commit)
                return true
            }
            
        case 53: // Escape
            let flush = context.flush()
            updateDisplay(client: client, preedit: "", committed: flush)
            return true
            
        default:
            // 일반 문자 처리
            if let char = characters.first {
                let ascii = Int(char.asciiValue ?? 0)
                let processed = context.processKey(Int32(ascii))
                let preedit = context.preeditString()
                let commit = context.commitString()
                updateDisplay(client: client, preedit: preedit, committed: commit)
                return processed
            }
        }
        
        return false
    }
    
    private func handleFlagsChanged(event: NSEvent, client: Any!) -> Bool {
        let flags = event.modifierFlags
        let capsLockFlagState = flags.contains(.capsLock)

        // Caps Lock 토글 감지 (keyCode 57)
        guard event.keyCode == 57 else {
            isCapsLockOn = capsLockFlagState
            return false
        }

        // 상태가 변경된 경우에만 처리
        if capsLockFlagState != isCapsLockOn {
            isCapsLockOn = capsLockFlagState

            if hangulContext != nil {
                if let context = hangulContext {
                    let flush = context.flush()
                    if !flush.isEmpty {
                        updateDisplay(client: client, preedit: "", committed: flush)
                    }
                }

                performLanguageToggle()
                return true
            }
        }

        return false
    }
    
    // 한/영 전환 수행
    private func performLanguageToggle() {
        // 현재 입력 소스 목록 가져오기
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else { return }
        let count = CFArrayGetCount(inputSources)
        
        // 현재 입력 소스
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        guard let currentSourceIDRef = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else { return }
        let currentSourceID = Unmanaged<CFString>.fromOpaque(currentSourceIDRef).takeUnretainedValue() as String
        
        // 다음 입력 소스 찾기
        var targetSource: TISInputSource?
        var targetModeInfo: (id: String, language: String)?

        for i in 0..<count {
            guard let source = CFArrayGetValueAtIndex(inputSources, i) else { continue }
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()

            guard let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else { continue }
            let sourceID = Unmanaged<CFString>.fromOpaque(sourceIDRef).takeUnretainedValue() as String

            // 현재 소스가 아니고 우리 입력기 중 하나인 경우
            if sourceID != currentSourceID && inputModeMapping[sourceID] != nil {
                targetSource = inputSource
                targetModeInfo = inputModeMapping[sourceID]
                break
            }
        }

        // 입력 소스 전환
        if let target = targetSource {
            if let modeInfo = targetModeInfo {
                switch modeInfo.language {
                case "ko":
                    setupKoreanMode()
                case "en":
                    setupEnglishMode()
                default:
                    setupKoreanMode()
                }
            }
            TISSelectInputSource(target)
        }
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
    
    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }    
}
