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
    
    public init() {}
    
    // 이벤트 처리 메인 함수  
    public func process(event: CGEvent, type: CGEventType) -> Events? {
        let typedKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        
        // flagsChanged 이벤트는 Caps Lock 등 시스템 키를 위해 통과
        if type == .flagsChanged {
            return Events(mainEvent: Unmanaged.passUnretained(event))
        }
        
        switch typedKeyCode {
        case kVK_Space:
            if type == .keyDown {
                isSpaceDown = true
                return nil // Space keyDown 소비
            } else if type == .keyUp {
                isSpaceDown = false
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
    
    // Half-QWERTY 매핑 테이블
    private let halfQwertyMapping: [Int: Int] = [
        // 왼손 -> 오른손 매핑
        kVK_ANSI_A: kVK_ANSI_Semicolon,
        kVK_ANSI_S: kVK_ANSI_L,
        kVK_ANSI_D: kVK_ANSI_K,
        kVK_ANSI_F: kVK_ANSI_J,
        kVK_ANSI_H: kVK_ANSI_G,
        kVK_ANSI_G: kVK_ANSI_H,
        kVK_ANSI_Z: kVK_ANSI_Slash,
        kVK_ANSI_X: kVK_ANSI_Period,
        kVK_ANSI_C: kVK_ANSI_Comma,
        kVK_ANSI_V: kVK_ANSI_M,
        kVK_ANSI_B: kVK_ANSI_N,
        kVK_ANSI_Q: kVK_ANSI_P,
        kVK_ANSI_W: kVK_ANSI_O,
        kVK_ANSI_E: kVK_ANSI_I,
        kVK_ANSI_R: kVK_ANSI_U,
        kVK_ANSI_Y: kVK_ANSI_T,
        
        // 오른손 -> 왼손 매핑
        kVK_ANSI_T: kVK_ANSI_Y,
        kVK_ANSI_O: kVK_ANSI_W,
        kVK_ANSI_U: kVK_ANSI_R,
        kVK_ANSI_I: kVK_ANSI_E,
        kVK_ANSI_P: kVK_ANSI_Q,
        kVK_ANSI_L: kVK_ANSI_S,
        kVK_ANSI_J: kVK_ANSI_F,
        kVK_ANSI_K: kVK_ANSI_D,
        kVK_ANSI_Semicolon: kVK_ANSI_A,
        kVK_ANSI_Comma: kVK_ANSI_C,
        kVK_ANSI_Slash: kVK_ANSI_Z,
        kVK_ANSI_N: kVK_ANSI_B,
        kVK_ANSI_M: kVK_ANSI_V,
        kVK_ANSI_Period: kVK_ANSI_X,   
    ]
}