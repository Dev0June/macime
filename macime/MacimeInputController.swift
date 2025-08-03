//
//  MacimeInputController.swift
//  macime
//
//  Created by JBK
//

import InputMethodKit

@objc(MacimeInputController)
open class MacimeInputController: IMKInputController {
    
    var hangulComposer: HangulComposer = HangulComposer()
    
    override open func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        NSLog("macime activated")
        self.hangulComposer.reset()
    }
    
    override open func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        NSLog("macime deactivated")
        self.commitComposition(sender)
    }
    
    override open func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else {
            return false
        }
        
        let keyCode = event.keyCode
        
        // 기본적인 키 처리
        if let characters = event.characters {
            for char in characters {
                if hangulComposer.process(char: char) {
                    updateDisplay(client: sender)
                    return true
                }
            }
        }
        
        if keyCode == 36 || keyCode == 49 {
            commitComposition(sender)
            return false
        }
        
        if keyCode == 51 {
            if hangulComposer.backspace() {
                updateDisplay(client: sender)
                return true
            }
        }
        
        return false
    }
    
    private func updateDisplay(client sender: Any!) {
        let composing = hangulComposer.getComposingText()
        if !composing.isEmpty {
            client()?.setMarkedText(composing, selectionRange: NSRange(location: composing.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        } else {
            client()?.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
    }
    
    override open func commitComposition(_ sender: Any!) {
        let finalText = hangulComposer.getFinalText()
        if !finalText.isEmpty {
            client()?.insertText(finalText, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        hangulComposer.reset()
        client()?.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}