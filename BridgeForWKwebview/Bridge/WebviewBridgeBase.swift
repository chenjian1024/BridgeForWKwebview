//
//  WebviewBridgeBase.swift
//  BridgeForWKwebview
//
//  Created by chenjian on 2019/5/16.
//  Copyright © 2019 chenjian. All rights reserved.
//

import UIKit
import WebKit

protocol WebViewJavascriptBridgeBaseDelegate {
    func evaluateJavascript(javascriptCommand: String) -> String
}

let kNewProtocolScheme: String = "https"
let kQueueHasMessage: String = "__wvjb_queue_message__"
let kBridgeLoaded: String = "__bridge_loaded__"

class WebviewBridgeBase: NSObject {
    
    static var logging: Bool = false
    static var logMaxLength: Int = 500
    var delegate: WebViewJavascriptBridgeBaseDelegate?
    var startupMessageQueue: [Any]?
    var responseCallbacks: Dictionary<String, WVJBResponseCallback>?
    var messageHandlers: Dictionary<String, WVJBHandler>?
    var messageHandler: WVJBHandler?
    var uniqueId: Int = 0
    
    override init() {
        super.init()
        messageHandlers = Dictionary<String, WVJBHandler>()
        startupMessageQueue = [Any]()
        responseCallbacks = Dictionary<String, WVJBResponseCallback>()
        uniqueId = 0
    }
    
    deinit {
        startupMessageQueue = nil
        responseCallbacks = nil
        messageHandlers = nil
    }
    
    static func enableLogging(){
        logging = true
    }
    
    static func setLogMaxLength(length: Int){
        logMaxLength = length
    }
    
    func reset() -> Void {
        
    }
    
    func sendData(data: Any?, responseCallback: WVJBResponseCallback?, handleName: String?) -> Void {
        guard let data = data else {return}
        var message = [String: Any]()
        message["data"] = data
        uniqueId += 1
        let callBackId = "objc_cb_\(uniqueId)"
        self.responseCallbacks?[callBackId] = responseCallback
        message["callbackId"] = callBackId
        if let handleName = handleName {
            message["handlerName"] = handleName
        }
        queueMessage(message: message)
    }
    
    func evaluateJavascript(javascriptCommand: String) {
        delegate?.evaluateJavascript(javascriptCommand: javascriptCommand)
    }
    
    func queueMessage(message: [String: Any]) {
        if startupMessageQueue != nil {
            self.startupMessageQueue?.append(message)
        } else {
            self.dispatchMessage(message: message)
        }
    }
    
    func dispatchMessage(message: [String: Any]) {
        var messageJSON = serializeMessage(message: message, pretty: false)
        messageJSON = messageJSON.replacingOccurrences(of: "\\", with: "\\\\")
         messageJSON = messageJSON.replacingOccurrences(of: "\"", with: "\\\"")
         messageJSON = messageJSON.replacingOccurrences(of: "\'", with: "\\\'")
         messageJSON = messageJSON.replacingOccurrences(of: "\n", with: "\\n")
         messageJSON = messageJSON.replacingOccurrences(of: "\r", with: "\\r")
//         messageJSON = messageJSON.replacingOccurrences(of: " \f", with: " \\f")
//         messageJSON = messageJSON.replacingOccurrences(of: " \u2028", with: "\\u2028")
//        messageJSON = messageJSON.replacingOccurrences(of: " \u2029", with: "\\u2029")
        let javascriptCommand: String = "WebViewJavascriptBridge._handleMessageFromObjC('\(messageJSON)')"
        if Thread.current == Thread.main {
           evaluateJavascript(javascriptCommand: javascriptCommand)
        } else {
            DispatchQueue.main.sync {
                self.evaluateJavascript(javascriptCommand: javascriptCommand)
            }
        }
    }
    
    func flushMessageQueue(messageQueueString: String?) -> Void {
        guard let messageQueueString = messageQueueString, !messageQueueString.isEmpty else {
            print("messageQueueString为空")
            return
        }
        let messages = deserializeMessageJSON(messagejSON: messageQueueString)
        for message in messages {
            if let message = message as? [String: Any] {
                if let responseId = message["responseId"] as? String  {
                    if let responseCallback = responseCallbacks?[responseId] {
                        responseCallback(message["responseData"] as Any)
                        responseCallbacks?.removeValue(forKey: responseId)
                    }
                } else {
                    var responseCallback: WVJBResponseCallback? = nil
                    if let callbackId = message["callbackId"] {
                        responseCallback = { responseData in
                            
                            if responseData == nil {
                              let message = ["responseId":callbackId, "responseData": NSNull()] as [String : Any]
                                self.queueMessage(message: message)
                            } else {
                                let message = ["responseId":callbackId, "responseData": responseData as Any] as [String : Any]
                                self.queueMessage(message: message)
                            }
                        }
                    } else {
                        responseCallback = { responseData in
                            // Do nothing
                        }
                    }
                    if let handlerName =  message["handlerName"] as? String, let handler = messageHandlers?[handlerName] {
                        handler(message["data"] as Any, responseCallback!);
                    }
                }
            } else {
                continue
            }
            
        }
    }
    
    func injectJavascriptFile() -> Void {
        guard let JSstring = WebviewBridgejs.preprocessorJSCode else { return }
        evaluateJavascript(javascriptCommand: JSstring)
        if let messageQueue = startupMessageQueue {
            for message in messageQueue {
                dispatchMessage(message: message as! [String : Any])
            }
            startupMessageQueue = nil
        }
    }
    
    func isWebViewJavascriptBridgeURL(url: URL) -> Bool {
        if !isSchemeMatch(url: url) {
            return false
        }
        return isBridgeLoadedURL(url: url) || isQueueMessageURL(url: url)
    }
    
    func isSchemeMatch(url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == kNewProtocolScheme ? true : false
    }
    
    func isQueueMessageURL(url: URL) -> Bool {
        let host = url.host?.lowercased()
        return isSchemeMatch(url: url) && host == kQueueHasMessage
    }
    
    func isBridgeLoadedURL(url: URL) -> Bool {
        let host = url.host?.lowercased()
        return isSchemeMatch(url: url) && host == kBridgeLoaded
    }
    
    func logUnknownMessage(url: URL) {
       print("WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command \(url.absoluteString)")
    }
    
    func webViewJavascriptCheckCommand() -> String {
        return "typeof WebViewJavascriptBridge == \'object\';"
    }
    
    func webViewJavascriptFetchQueyCommand() -> String {
        return "WebViewJavascriptBridge._fetchQueue();"
    }
    
    func disableJavscriptAlertBoxSafetyTimeout() {
        sendData(data: nil, responseCallback: nil, handleName: "_disableJavascriptAlertBoxSafetyTimeout")
    }
    
    func serializeMessage(message: [String: Any], pretty: Bool) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: (pretty ? .prettyPrinted : []))
            return  String(data: data, encoding: String.Encoding.utf8) ?? ""
        } catch {
            print("序列化message的时候异常")
        }
        return ""
    }
    
    func deserializeMessageJSON(messagejSON: String) -> [Any] {
        do {
            let messages = try JSONSerialization.jsonObject(with: messagejSON.data(using: String.Encoding.utf8) ?? Data(), options: JSONSerialization.ReadingOptions.allowFragments) as? [Any] ?? [Any]()
            return messages
        } catch {
            print("反序列化message的时候异常")
        }
        return [Any]()
    }
}
