//
//  HangulComposer.swift
//  macime
//
//  Created by JBK
//

import Foundation

class HangulComposer {
    private var chosung = ""
    private var jungsung = ""
    private var jongsung = ""
    private var completedText = ""
    
    // 2벌식 키보드 매핑
    private let consonantMap: [Character: String] = [
        "r": "ㄱ", "R": "ㄲ",
        "s": "ㄴ",
        "e": "ㄷ", "E": "ㄸ",
        "f": "ㄹ",
        "a": "ㅁ",
        "q": "ㅂ", "Q": "ㅃ",
        "t": "ㅅ", "T": "ㅆ",
        "d": "ㅇ",
        "w": "ㅈ", "W": "ㅉ",
        "c": "ㅊ",
        "z": "ㅋ",
        "x": "ㅌ",
        "v": "ㅍ",
        "g": "ㅎ"
    ]
    
    private let vowelMap: [Character: String] = [
        "k": "ㅏ",
        "o": "ㅐ",
        "i": "ㅑ",
        "O": "ㅒ",
        "j": "ㅓ",
        "u": "ㅔ",
        "h": "ㅕ",
        "P": "ㅖ",
        "y": "ㅗ",
        "n": "ㅘ",
        "b": "ㅙ",
        "m": "ㅚ",
        "l": "ㅛ",
        "p": "ㅜ",
        ";": "ㅝ",
        "'": "ㅞ",
        "/": "ㅟ",
        "0": "ㅠ",
        "[": "ㅡ",
        "]": "ㅢ",
        "\\": "ㅣ"
    ]
    
    func process(char: Character) -> Bool {
        // 한글 문자가 아니면 처리하지 않음
        if let consonant = consonantMap[char] {
            return processConsonant(consonant)
        } else if let vowel = vowelMap[char] {
            return processVowel(vowel)
        }
        
        // 한글이 아닌 문자는 바로 완성 텍스트에 추가
        if !chosung.isEmpty || !jungsung.isEmpty || !jongsung.isEmpty {
            finishCurrentSyllable()
        }
        completedText += String(char)
        return true
    }
    
    private func processConsonant(_ consonant: String) -> Bool {
        if chosung.isEmpty {
            // 초성 입력
            chosung = consonant
        } else if jungsung.isEmpty {
            // 초성은 있는데 중성이 없으면 기존 조합 완료하고 새로 시작
            finishCurrentSyllable()
            chosung = consonant
        } else {
            // 초성, 중성이 있으면 종성으로 처리
            if jongsung.isEmpty {
                jongsung = consonant
            } else {
                // 종성이 이미 있으면 기존 조합 완료하고 새로 시작
                finishCurrentSyllable()
                chosung = consonant
            }
        }
        return true
    }
    
    private func processVowel(_ vowel: String) -> Bool {
        if chosung.isEmpty {
            // 초성 없이 중성이 오면 바로 완성 텍스트에 추가
            completedText += vowel
        } else if jungsung.isEmpty {
            // 초성 다음에 중성
            jungsung = vowel
        } else {
            // 중성이 이미 있으면 기존 조합 완료하고 새로 시작
            finishCurrentSyllable()
            completedText += vowel
        }
        return true
    }
    
    func backspace() -> Bool {
        if !jongsung.isEmpty {
            jongsung = ""
        } else if !jungsung.isEmpty {
            jungsung = ""
        } else if !chosung.isEmpty {
            chosung = ""
        } else if !completedText.isEmpty {
            completedText = String(completedText.dropLast())
        } else {
            return false
        }
        return true
    }
    
    func getComposingText() -> String {
        if chosung.isEmpty && jungsung.isEmpty && jongsung.isEmpty {
            return ""
        }
        
        let syllable = combineHangul(chosung: chosung, jungsung: jungsung, jongsung: jongsung)
        return syllable
    }
    
    func getFinalText() -> String {
        var result = completedText
        if !chosung.isEmpty || !jungsung.isEmpty || !jongsung.isEmpty {
            result += combineHangul(chosung: chosung, jungsung: jungsung, jongsung: jongsung)
        }
        return result
    }
    
    func reset() {
        chosung = ""
        jungsung = ""
        jongsung = ""
        completedText = ""
    }
    
    private func finishCurrentSyllable() {
        if !chosung.isEmpty || !jungsung.isEmpty || !jongsung.isEmpty {
            completedText += combineHangul(chosung: chosung, jungsung: jungsung, jongsung: jongsung)
            chosung = ""
            jungsung = ""
            jongsung = ""
        }
    }
    
    private func combineHangul(chosung: String, jungsung: String, jongsung: String) -> String {
        // 간단한 한글 조합 (유니코드 조합)
        if chosung.isEmpty && jungsung.isEmpty && jongsung.isEmpty {
            return ""
        }
        
        if jungsung.isEmpty {
            return chosung + jongsung
        }
        
        // 초성, 중성, 종성을 유니코드로 조합
        let chosungIndex = getChosungIndex(chosung)
        let jungsungIndex = getJungsungIndex(jungsung)
        let jongsungIndex = getJongsungIndex(jongsung)
        
        if chosungIndex >= 0 && jungsungIndex >= 0 {
            let unicodeValue = 0xAC00 + chosungIndex * 588 + jungsungIndex * 28 + jongsungIndex
            if let scalar = UnicodeScalar(unicodeValue) {
                return String(scalar)
            }
        }
        
        return chosung + jungsung + jongsung
    }
    
    private func getChosungIndex(_ chosung: String) -> Int {
        let chosungList = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
        return chosungList.firstIndex(of: chosung) ?? -1
    }
    
    private func getJungsungIndex(_ jungsung: String) -> Int {
        let jungsungList = ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
        return jungsungList.firstIndex(of: jungsung) ?? -1
    }
    
    private func getJongsungIndex(_ jongsung: String) -> Int {
        if jongsung.isEmpty { return 0 }
        let jongsungList = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
        return jongsungList.firstIndex(of: jongsung) ?? 0
    }
}