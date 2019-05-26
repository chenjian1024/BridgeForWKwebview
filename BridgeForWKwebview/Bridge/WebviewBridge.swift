//
//  WebviewBridge.swift
//  BridgeForWKwebview
//
//  Created by chenjian on 2019/5/16.
//  Copyright © 2019 chenjian. All rights reserved.
//

import UIKit
import WebKit

typealias WVJBResponseCallback = ((Any?) -> Void)
typealias WVJBHandler = ((Any, WVJBResponseCallback) -> Void)

class WebviewBridge: NSObject {
    
    var webview: WKWebView?
    var webviewDelegate: Any?
    var base: WebviewBridgeBase?
    
    
    static func bridgeForWebview(webview: WKWebView) -> WebviewBridge {
        return bridge(webview: webview)
    }
    
    static func bridge(webview: WKWebView) -> WebviewBridge {
        let bridge =  WebviewBridge()
        bridge.setUpInstance(webview: webview)
        bridge.reset()
        return bridge
    }
    
    static func enableLogging(){
        
    }
    
    deinit {
        base = nil
        webview = nil
        webviewDelegate = nil
        webview?.navigationDelegate = nil
    }
    
    func send(data: Any) {
        send(data: data, responseCallback: nil)
    }
    
    func send(data: Any, responseCallback: WVJBResponseCallback?) {
        base?.sendData(data: data, responseCallback: responseCallback, handleName: nil)
    }
    
    func callHandler(handlerName: String) {
        callHandler(handlerName: handlerName, data: nil,responseCallback: nil)
    }
    
    func callHandler(handlerName: String, data: Any?) {
        callHandler(handlerName: handlerName, data: data, responseCallback: nil)
    }
    
    func callHandler(handlerName: String?, data: Any?, responseCallback: WVJBResponseCallback?) {
        base?.sendData(data: data, responseCallback: responseCallback, handleName: handlerName)
    }
    
    func registerHandler(handlerName: String, handler: @escaping WVJBHandler) {
        base?.messageHandlers?[handlerName] = handler
    }
    
    func removeHandler(handlerName: String) {
        base?.messageHandlers?.removeValue(forKey: handlerName)
    }
    
    func reset() -> Void {
        base?.reset()
    }
    
    func setWebViewDelegate(webViewDelegate: Any) {
        self.webviewDelegate = webViewDelegate
    }
    
    func disableJavscriptAlertBoxSafetyTimeout() {
        base?.disableJavscriptAlertBoxSafetyTimeout()
    }
    
    func setUpInstance(webview: WKWebView){
        self.webview = webview
        self.webview?.navigationDelegate = self
        base = WebviewBridgeBase()
        base?.delegate = self
    }
    
    func WKFlushMessageQueue () {
        if let base = base {
            webview?.evaluateJavaScript(base.webViewJavascriptFetchQueyCommand(), completionHandler: { (result, error) in
                if let error = error {
                    print("WebViewJavascriptBridge: WARNING: Error when trying to fetch data from WKWebView:\(error)")
                }
                if let result = result as? String {
                    base.flushMessageQueue(messageQueueString: result)
                }
            })
        }
    }
    
}

extension WebviewBridge: WKNavigationDelegate, WebViewJavascriptBridgeBaseDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webview != self.webview { return }
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, didFinish: navigation)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webview != self.webview { return }
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
        } else {
            decisionHandler(WKNavigationResponsePolicy.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if webview != self.webview { return }
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, didReceive: challenge, completionHandler: completionHandler)
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling,nil)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if webview != self.webview { return }
        if let url = navigationAction.request.url, let base = base {
            if base.isWebViewJavascriptBridgeURL(url: url) {
                if base.isBridgeLoadedURL(url: url) {
                    base.injectJavascriptFile()
                } else if base.isQueueMessageURL(url: url) {
                    WKFlushMessageQueue()
                } else {
                    base.logUnknownMessage(url: url)
                }
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
            }
        }
        
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
        
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, didStartProvisionalNavigation: navigation)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let delegate = webviewDelegate as? WKNavigationDelegate {
            delegate.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        }
    }
    
    func evaluateJavascript(javascriptCommand: String) -> String {
        webview?.evaluateJavaScript(javascriptCommand, completionHandler: { (data, error) in
            if let error = error {
                print(error.localizedDescription)
            }
            print("injectjsCallBackData:\(data)")
        })
        return ""
    }
    
}
