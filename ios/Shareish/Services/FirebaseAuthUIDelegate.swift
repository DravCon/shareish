//
//  FirebaseAuthUIDelegate.swift
//  Shareish
//

import Foundation

#if canImport(FirebaseAuth) && canImport(UIKit)
import FirebaseAuth
import UIKit
#endif

#if canImport(FirebaseAuth) && canImport(UIKit)
/// Presents Firebase reCAPTCHA / Safari UI when needed for Phone Auth.
final class FirebaseAuthUIDelegate: NSObject, AuthUIDelegate {

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.windows.first { $0.isKeyWindow }
        let root = base ?? window?.rootViewController
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController ?? nav)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController ?? tab)
        }
        return root
    }

    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let top = Self.topViewController() else {
            completion?()
            return
        }
        top.present(viewController, animated: animated, completion: completion)
    }

    func dismiss(animated: Bool, completion: (() -> Void)?) {
        guard let top = Self.topViewController() else {
            completion?()
            return
        }
        if top.presentedViewController != nil {
            top.dismiss(animated: animated, completion: completion)
        } else {
            completion?()
        }
    }
}
#endif
