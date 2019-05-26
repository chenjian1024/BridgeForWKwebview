//
//  WebviewBridgejs.swift
//  BridgeForWKwebview
//
//  Created by chenjian on 2019/5/21.
//  Copyright © 2019 chenjian. All rights reserved.
//

import UIKit


class WebviewBridgejs: NSObject {
    static let preprocessorJSCode: String? = {
        if let filePath = Bundle.main.path(forResource: "inject", ofType: "js") {
            let url = URL(fileURLWithPath: filePath)
            do {
                let stringData = try Data(contentsOf: url)
                let injectjs = String(data: stringData, encoding: String.Encoding.utf8)
                return injectjs
            } catch {
              return nil
            }
        } else {
           return nil
        }
    }()
}
