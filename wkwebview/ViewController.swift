//
//  ViewController.swift
//  wkwebview
//
//  Created by Colin Milhench on 06/08/2019.
//  Copyright © 2019 Colin Milhench. All rights reserved.
//

import UIKit
import WebKit

// Example content filtering rules
let rules = """
[
    {
        "trigger": { "url-filter": ".*" },
        "action": { "type": "css-display-none", "selector": "nav, #see-also, #globalfooter-wrapper" }
    }
]
"""

// Example javascript source to be injected
let source = """
    document.addEventListener ("DOMContentLoaded", function() {
        document.body.style.color = "#333";
        document.addEventListener('click', function () {
            window.webkit.messageHandlers.notification.postMessage('Hello, World!')
        });
    });
"""

class ViewController: UIViewController {
    var webView: WKWebView!
    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        let userContentController = WKUserContentController()
        userContentController.add(self, name: "notification")

        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(script)

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController

        let layoutGuide = view.safeAreaLayoutGuide

        // Create a web view
        webView = WKWebView.init(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true

        // Create a progress bar view
        progressView = UIProgressView(progressViewStyle: .default)

        view.addSubview(progressView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        progressView.heightAnchor.constraint(equalToConstant: 2).isActive = true

        // Create navigation buttons
        backButton = UIBarButtonItem.init(image: UIImage(named: "arrow 18"), style: .plain, target: self, action: #selector(goBack))
        forwardButton = UIBarButtonItem.init(image: UIImage(named: "arrow 17"), style: .plain, target: self, action: #selector(goForward))
        navigationItem.leftBarButtonItems = [backButton, forwardButton]

        // Compile the content rules
        let ctx = DispatchGroup()
        ctx.enter()

        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "ContentBlockingRules", encodedContentRuleList: rules, completionHandler: { (rules, error) in
                defer { ctx.leave() }
                guard let rules = rules, error == nil else { return }
                let configuration = self.webView.configuration
                configuration.userContentController.add(rules)
        })

        // Load the url
        let url = URL(string: "https://developer.apple.com/documentation/safariservices/creating_a_content_blocker")!
        self.webView.load(URLRequest(url: url))
    }

    @objc func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    // Handle KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "loading" {
            // Update history buttons
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
        } else if keyPath == "title" {
            // ypdate title
            if let title = webView.title {
                print(title)
            }
        } else if keyPath == "estimatedProgress" {
            // update progress bar
            print(webView.estimatedProgress)
            progressView.progress = Float(webView.estimatedProgress)
        }
    }

}

extension ViewController: WKNavigationDelegate {
    // only allow specific hosts to load
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.host != "developer.apple.com" {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Show the progress bar
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.progressView.alpha = 1
        })
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide the progress bar
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.progressView.alpha = 0
        })
        // Exacute some javascript within the loaded page
        let source = "window.webkit.messageHandlers.notification.postMessage('Hi there!')"
        webView.evaluateJavaScript(source) { (_, error) in
            if let error = error { print(error) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Hide the progress bar
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.progressView.alpha = 0
        })
    }
}

extension ViewController: WKScriptMessageHandler {
    // Recieve messages from the page sent with `window.webkit.messageHandlers.[].postMessage(payload)`
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body)
    }

}
