//
//  ViewController.swift
//  BridgeForWKwebview
//
//  Created by chenjian on 2019/5/16.
//  Copyright © 2019 chenjian. All rights reserved.
//

import UIKit
import WebKit
class ViewController: UIViewController {
    var bridge: WebviewBridge?
    let wkwebview: WKWebView = {
        let wkwebview = WKWebView()
        return wkwebview
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        wkwebview.frame = view.frame
        view.addSubview(wkwebview)
        let button = UIButton(frame: CGRect(origin: CGPoint(x: 300,y: 150), size: CGSize(width: 75, height: 50)))
        button.setTitle("callJsHander", for: UIControl.State.normal)
        button.backgroundColor = UIColor.red
        button.setTitleColor(UIColor.green, for: UIControl.State.normal)
        button.addTarget(self, action: #selector(callJsHandler), for: UIControl.Event.touchUpInside)
        view.addSubview(button)
        bridge = WebviewBridge.bridgeForWebview(webview: wkwebview)
        bridge?.webviewDelegate = self
        bridge?.registerHandler(handlerName: "testObjcCallback", handler: { (data, responesCallback) in
            print("testObjcCallback called: \(data)")
            responesCallback("Response from testObjcCallback")
        })
        loadExamlePage()
    }
    
    func loadExamlePage() {
        guard let pagePath = Bundle.main.path(forResource: "ExampleApp", ofType: "html") else { return}
        let baseurl = URL(fileURLWithPath: pagePath)
        do {
            let htmlString = try String(contentsOfFile: pagePath, encoding: String.Encoding.utf8)
            wkwebview.loadHTMLString(htmlString, baseURL: baseurl)
        } catch  {
            print("loadpageerror:\(error.localizedDescription)")
        }
    }
    
    @objc func callJsHandler() {
        bridge?.callHandler(handlerName: "testJavascriptHandler", data: "buttonClick" , responseCallback: nil)
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("wkwebview did start navigate")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("wkwebview did finsh navigate")
    }
}

