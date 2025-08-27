//
//  KeyMapper.swift  
//  macime
//
//  Created by JBK on 2025/08/12.
//  Half-QWERTY 키 매핑 및 처리
//

import Foundation
import CoreGraphics
import Carbon.HIToolbox
import AppKit

// 이벤트 구조체
public struct Events {
    public let preEvents: [Unmanaged<CGEvent>]
    public let mainEvent: Unmanaged<CGEvent>?
    
    public init(preEvents: [Unmanaged<CGEvent>] = [], mainEvent: Unmanaged<CGEvent>? = nil) {
        self.preEvents = preEvents
        self.mainEvent = mainEvent
    }
}

// Half-QWERTY 키 매핑 및 처리 클래스
public final class KeyMapper {
    private var isSpaceDown = false
    private var typedCharacterWhileSpaceWasDown = false
    
    // macOS 시스템 키 반복 설정 사용
    private var spaceRepeatTimer: DispatchSourceTimer?
    private var allowSpaceRepeat = false
    
    // Caps Lock 상태 추적
    private var capsLockPressTime: DispatchTime?
    private var capsLockTimer: DispatchSourceTimer?
    
    public init() {}
    
    // 이벤트 처리 메인 함수  
    public func process(event: CGEvent, type: CGEventType) -> Events? {
        let typedKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        
        // Caps Lock 처리
        if type == .flagsChanged {
            return handleCapsLockFlagsChanged(event: event)
        }
        
        switch typedKeyCode {
        case kVK_Space:
            if type == .keyDown {
                if !isSpaceDown {
                    // 첫 번째 Space keyDown
                    isSpaceDown = true
                    allowSpaceRepeat = false
                    
                    // macOS 시스템 키 반복 딜레이 후 반복 활성화
                    startSpaceRepeatTimer()
                    
                    return nil // 첫 번째 keyDown 소비
                } else {
                    // 키 반복 중인 keyDown
                    if allowSpaceRepeat {
                        return Events(mainEvent: Unmanaged.passUnretained(event))
                    } else {
                        return nil // 아직 타이머 전이므로 소비
                    }
                }
            } else if type == .keyUp {
                isSpaceDown = false
                allowSpaceRepeat = false
                stopSpaceRepeatTimer()
                
                if typedCharacterWhileSpaceWasDown {
                    typedCharacterWhileSpaceWasDown = false
                    return nil // Space keyUp 소비
                } else {
                    // 실제 Space 키 누르기 - keyDown을 preEvent로, keyUp을 mainEvent로
                    if let spaceDownEvent = CGEvent(
                        keyboardEventSource: CGEventSource(event: event),
                        virtualKey: CGKeyCode(kVK_Space),
                        keyDown: true
                    ) {
                        return Events(
                            preEvents: [Unmanaged.passRetained(spaceDownEvent)],
                            mainEvent: Unmanaged.passUnretained(event)
                        )
                    }
                    return Events(mainEvent: Unmanaged.passUnretained(event))
                }
            }
            
        default:
            if isSpaceDown {
                // Half-QWERTY 매핑 적용
                typedCharacterWhileSpaceWasDown = true
                
                if let newKeyCode = getMappedKey(for: typedKeyCode) {
                    if let newEvent = CGEvent(
                        keyboardEventSource: CGEventSource(event: event),
                        virtualKey: CGKeyCode(newKeyCode),
                        keyDown: type == .keyDown
                    ) {
                        return Events(mainEvent: Unmanaged.passRetained(newEvent))
                    }
                }
            }
        }
        
        return Events(mainEvent: Unmanaged.passUnretained(event))
    }
    
    // half-qwerty 레이아웃용 매핑된 키 코드 반환 (Space + 키 조합)
    private func getMappedKey(for keyCode: Int) -> Int? {
        return halfQwertyMapping[keyCode]
    }
    
    // macOS 시스템 키 반복 설정을 사용한 타이머 (첫 글자 딜레이 추가)
    private func startSpaceRepeatTimer() {
        stopSpaceRepeatTimer() // 기존 타이머 정리
        
        spaceRepeatTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        
        // macOS 시스템 키 반복 딜레이 가져오기 (초 → 밀리초)
        let systemDelay = NSEvent.keyRepeatDelay * 1000
        
        // 첫 글자 딜레이를 시스템 딜레이보다 더 길게 설정 (2.5배)
        let firstCharDelayMs = Int(systemDelay * 2.5)
        
        spaceRepeatTimer?.schedule(deadline: .now() + .milliseconds(firstCharDelayMs))
        spaceRepeatTimer?.setEventHandler { [weak self] in
            self?.allowSpaceRepeat = true
        }
        spaceRepeatTimer?.resume()
    }
    
    private func stopSpaceRepeatTimer() {
        spaceRepeatTimer?.cancel()
        spaceRepeatTimer = nil
    }
    
    // Caps Lock flagsChanged 이벤트 처리
    private func handleCapsLockFlagsChanged(event: CGEvent) -> Events? {
        let flags = event.flags
        let isCapsLockPressed = flags.contains(.maskAlphaShift)
        
        if isCapsLockPressed {
            // Caps Lock이 눌렸을 때
            if capsLockPressTime == nil {
                capsLockPressTime = .now()
                startCapsLockTimer()
                return nil // 이벤트 소비 - 타이머로 처리할 것
            }
        } else {
            // Caps Lock이 해제되었을 때
            if let pressTime = capsLockPressTime {
                let pressDuration = DispatchTime.now().uptimeNanoseconds - pressTime.uptimeNanoseconds
                let durationInMs = pressDuration / 1_000_000 // 나노초를 밀리초로 변환
                
                stopCapsLockTimer()
                capsLockPressTime = nil
                
                // 시스템 키 반복 딜레이와 비교
                let systemDelayMs = NSEvent.keyRepeatDelay * 1000
                
                if durationInMs < UInt64(systemDelayMs) { // 시스템 딜레이 이하면 짧은 누르기 - 한/영 전환
                    // 한/영 전환 이벤트 생성 및 전송
                    sendLanguageToggleEvent()
                    return nil // 이벤트 소비
                }
                // 길게 눌렀을 경우는 시스템 대문자 토글이 이미 처리됨
            }
        }
        
        // 다른 flag 변경사항은 통과
        return Events(mainEvent: Unmanaged.passUnretained(event))
    }
    
    // macOS 시스템 키 반복 설정을 사용한 Caps Lock 타이머
    private func startCapsLockTimer() {
        stopCapsLockTimer()
        
        capsLockTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        
        // macOS 시스템 키 반복 딜레이 사용 (초 → 밀리초)
        let systemDelay = NSEvent.keyRepeatDelay * 1000
        let delayMs = Int(systemDelay)
        
        capsLockTimer?.schedule(deadline: .now() + .milliseconds(delayMs))
        capsLockTimer?.setEventHandler { [weak self] in
            // 길게 누르기가 확정되면 시스템 Caps Lock 토글 허용
            self?.allowSystemCapsLockToggle()
        }
        capsLockTimer?.resume()
    }
    
    private func stopCapsLockTimer() {
        capsLockTimer?.cancel()
        capsLockTimer = nil
    }
    
    // 시스템 Caps Lock 토글 허용
    private func allowSystemCapsLockToggle() {
        // 현재 Caps Lock 상태를 시스템에 반영하도록 이벤트 생성
        if let source = CGEventSource(stateID: .hidSystemState) {
            let capsLockEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_CapsLock), keyDown: false)
            capsLockEvent?.flags = .maskAlphaShift
            capsLockEvent?.post(tap: .cghidEventTap)
        }
    }
    
    // 한/영 전환 이벤트 전송
    private func sendLanguageToggleEvent() {
        // Cmd + Space (기본 macOS 입력 소스 전환)
        if let source = CGEventSource(stateID: .hidSystemState) {
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
            let spaceDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: true)
            let spaceUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: false)
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
            
            cmdDown?.flags = .maskCommand
            spaceDown?.flags = .maskCommand
            spaceUp?.flags = .maskCommand
            
            // 순차적으로 이벤트 전송
            cmdDown?.post(tap: .cghidEventTap)
            spaceDown?.post(tap: .cghidEventTap)
            spaceUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
        }
    }
    
    // Half-QWERTY 매핑 테이블
    private let halfQwertyMapping: [Int: Int] = [
        // 왼손 -> 오른손 매핑
        kVK_ANSI_Q: kVK_ANSI_P,
        kVK_ANSI_W: kVK_ANSI_O,
        kVK_ANSI_E: kVK_ANSI_I,
        kVK_ANSI_R: kVK_ANSI_U,
        kVK_ANSI_T: kVK_ANSI_Y,

        kVK_ANSI_A: kVK_ANSI_Semicolon,
        kVK_ANSI_S: kVK_ANSI_L,
        kVK_ANSI_D: kVK_ANSI_K,
        kVK_ANSI_F: kVK_ANSI_J,
        kVK_ANSI_G: kVK_ANSI_H,

        kVK_ANSI_Z: kVK_ANSI_Slash,
        kVK_ANSI_X: kVK_ANSI_Period,
        kVK_ANSI_C: kVK_ANSI_Comma,
        kVK_ANSI_V: kVK_ANSI_M,
        kVK_ANSI_B: kVK_ANSI_N,
        
        // 오른손 -> 왼손 매핑
        kVK_ANSI_Y: kVK_ANSI_T,
        kVK_ANSI_U: kVK_ANSI_R,
        kVK_ANSI_I: kVK_ANSI_E,
        kVK_ANSI_O: kVK_ANSI_W,
        kVK_ANSI_P: kVK_ANSI_Q,

        kVK_ANSI_H: kVK_ANSI_G,
        kVK_ANSI_J: kVK_ANSI_F,
        kVK_ANSI_K: kVK_ANSI_D,
        kVK_ANSI_L: kVK_ANSI_S,
        kVK_ANSI_Semicolon: kVK_ANSI_A,
        
        kVK_ANSI_N: kVK_ANSI_B,
        kVK_ANSI_M: kVK_ANSI_V,
        kVK_ANSI_Comma: kVK_ANSI_C,
        kVK_ANSI_Period: kVK_ANSI_X, 
        kVK_ANSI_Slash: kVK_ANSI_Z,  
    ]
}