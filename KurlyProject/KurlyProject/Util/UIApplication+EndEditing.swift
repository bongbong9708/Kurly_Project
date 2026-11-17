//
//  UIApplication+EndEditing.swift
//  KurlyProject
//

import UIKit

extension UIApplication {

    /// 현재 키보드를 내린다.
    ///
    /// iOS 17에는 `.searchable` 검색바의 포커스를 바꾸는 SwiftUI API(`.searchFocused`, iOS 18+)가 없어,
    /// 포커스를 가진 응답자(first responder)에게 포커스를 놓으라는 동작을 보낸다.
    /// 대상을 `nil`로 주면 현재 포커스를 가진 응답자가 받는다
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
