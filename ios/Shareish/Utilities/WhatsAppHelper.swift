//
//  WhatsAppHelper.swift
//  Shareish
//

import UIKit

enum WhatsAppHelper {
    static func open(_ urlString: String) {
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
