//
//  EventHandler.swift
//  macime
//
//  Created by JBK on 2025/08/12.
//  CGEvent 기반 이벤트 핸들러
//

import Foundation
import CoreGraphics
import Carbon.HIToolbox

// CGEvent tap 관리용 이벤트 핸들러
public final class EventHandler {
    private var isEnabled = false
    private var eventTap: CFMachPort?
    private let keyMapper = KeyMapper()
    
    public init() {}
    
    // 이벤트 핸들러 시작
    public func start() -> Bool {
        guard !isEnabled else { return true }
        
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue | 1 << CGEventType.flagsChanged.rawValue
        
        let callbackTrampoline: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) in
            guard let userInfo = userInfo else {
                return Unmanaged.passRetained(event)
            }
            let unsafeMapper = Unmanaged<KeyMapper>.fromOpaque(userInfo).takeUnretainedValue()
            let events = unsafeMapper.process(event: event, type: type)
            
            // 사전 이벤트 전송
            events?.preEvents.forEach { preEvent in
                preEvent.takeUnretainedValue().tapPostEvent(proxy)
            }
            
            return events?.mainEvent
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callbackTrampoline,
            userInfo: Unmanaged.passUnretained(keyMapper).toOpaque()
        )
        
        guard let eventTap = eventTap else { return false }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEnabled = true
        
        return true
    }
    
    public func stop() {
        guard eventTap != nil, isEnabled else { return }
        CFMachPortInvalidate(eventTap)
        eventTap = nil
        isEnabled = false
    }
    
    deinit {
        stop()
    }
}