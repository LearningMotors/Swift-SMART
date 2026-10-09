//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/15/14.
//  Copyright 2014 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
#if os(iOS)

import UIKit
import WebKit
#if !NO_MODULE_IMPORT
import Base
#endif


/**
A simple iOS web view controller that allows you to display the login/authorization screen.
*/
open class OAuth2WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
	
	/// Handle to the OAuth2 instance in play, only used for debug lugging at this time.
	var oauth: OAuth2?
	
	/// The URL to load on first show.
	open var startURL: URL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && isViewLoaded {
				load(url: startURL!)
			}
		}
	}
	
	/// The URL string to intercept and respond to.
	var interceptURLString: String? {
		didSet(oldURL) {
			if let interceptURLString = interceptURLString {
				if let url = URL(string: interceptURLString) {
					interceptComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
				}
				else {
					oauth?.logger?.debug("OAuth2", msg: "Failed to parse URL \(interceptURLString), discarding")
					self.interceptURLString = nil
				}
			}
			else {
				interceptComponents = nil
			}
		}
	}
	var interceptComponents: URLComponents?
	
	/// Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. Return a Bool indicating
	/// that you've intercepted the URL.
	var onIntercept: ((URL) -> Bool)?
	
	/// Called when the web view is about to be dismissed. The Bool indicates whether the request was (user-)canceled.
	var onWillDismiss: ((_ didCancel: Bool) -> Void)?
	
	/// Assign to override the back button, shown when it's possible to go back in history. Will adjust target/action accordingly.
	open var backButton: UIBarButtonItem? {
		didSet {
			if let backButton = backButton {
				backButton.target = self
				backButton.action = #selector(OAuth2WebViewController.goBack(_:))
			}
		}
	}
	
	var showCancelButton = true
	var cancelButton: UIBarButtonItem?
	
	/// Our web view.
	var webView: WKWebView?

	/// Suppresses a second external open when both `decidePolicyFor` and
	/// `createWebViewWith` see the same custom-scheme navigation.
	private var lastHandledPopup: (url: URL, at: Date)?

	/// Remembers whether the redirect was consumed, so the second delegate call cancels too.
	private var lastIntercept: (url: URL, at: Date, cancel: Bool)?

	/// Second windows opened by the login page (`window.open`, `target=_blank`).
	private var popups: [OAuth2PopupViewController] = []

	/// The authorize URL is loaded once. A later appearance is a return from a popup,
	/// and reloading here would wipe the Epic page the popup is talking to.
	private var didStartInitialLoad = false
	
	/// An overlay view containing a spinner.
	var loadingView: UIView?
	
	init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Handling
	
	override open func loadView() {
		edgesForExtendedLayout = .all
		extendedLayoutIncludesOpaqueBars = true

		super.loadView()
		view.backgroundColor = UIColor.white
		
		if showCancelButton {
			cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(OAuth2WebViewController.cancel(_:)))
			navigationItem.rightBarButtonItem = cancelButton
		}
		navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
		
		// create a web view
		let web = WKWebView()
		web.translatesAutoresizingMaskIntoConstraints = false
		web.scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
		web.navigationDelegate = self
		web.uiDelegate = self
		
		view.addSubview(web)
		let views = ["web": web]
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[web]|", options: [], metrics: nil, views: views))
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[web]|", options: [], metrics: nil, views: views))
		webView = web
	}
	
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if didStartInitialLoad {
			return
		}
		didStartInitialLoad = true
		trace("login web view appeared url=\(OAuth2EmbeddedNavigationPolicy.redacted(startURL))")
		
		if let web = webView, !web.canGoBack {
			if nil != startURL {
				load(url: startURL!)
			}
			else {
				web.loadHTMLString("There is no `startURL`", baseURL: nil)
			}
		}
	}
	
	func showHideBackButton(_ show: Bool) {
		if show {
			let bb = backButton ?? UIBarButtonItem(barButtonSystemItem: .rewind, target: self, action: #selector(OAuth2WebViewController.goBack(_:)))
			navigationItem.leftBarButtonItem = bb
		}
		else {
			navigationItem.leftBarButtonItem = nil
		}
	}
	
	func showLoadingIndicator() {
		// TODO: implement
	}
	
	func hideLoadingIndicator() {
		// TODO: implement
	}
	
	func showErrorMessage(_ message: String, animated: Bool) {
		NSLog("Error: \(message)")
	}
	
	
	// MARK: - Actions
	
	open func load(url: URL) {
		let _ = webView?.load(URLRequest(url: url))
	}
	
	@objc func goBack(_ sender: AnyObject?) {
		let _ = webView?.goBack()
	}
	
	@objc func cancel(_ sender: AnyObject?) {
		dismiss(asCancel: true, animated: (nil != sender) ? true : false)
	}
	
	override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
		dismiss(asCancel: false, animated: flag, completion: completion)
	}
	
	func dismiss(asCancel: Bool, animated: Bool, completion: (() -> Void)? = nil) {
		trace("login sheet dismissed cancel=\(asCancel) popups=\(popups.count)", level: asCancel ? SMARTServerLog.warn : SMARTServerLog.info)
		popups.forEach { $0.popupWebView.stopLoading() }
		popups.removeAll()
		webView?.stopLoading()
		
		if nil != self.onWillDismiss {
			self.onWillDismiss!(asCancel)
		}
		super.dismiss(animated: animated, completion: completion)
	}
	
	
	// MARK: - Web View Delegate
	
	open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
		let decision = OAuth2EmbeddedNavigationPolicy.decide(
			url: navigationAction.request.url,
			targetFrameIsNil: navigationAction.targetFrame == nil,
			intercept: interceptComponents
		)
		switch decision {
		case .intercept:
			guard let url = navigationAction.request.url, let onIntercept = onIntercept else {
				decisionHandler(.allow)
				return
			}
			trace(navigationSummary("redirect intercepted", action: navigationAction, webView: webView))
			if interceptDecision(for: url, onIntercept: onIntercept) {
				decisionHandler(.cancel)
			}
			else {
				decisionHandler(.allow)
			}
		case .openExternally:
			trace(navigationSummary("open externally", action: navigationAction, webView: webView), level: SMARTServerLog.warn)
			if let url = navigationAction.request.url, claimPopup(url) {
				openExternally(url)
			}
			decisionHandler(.cancel)
		case .presentPopup:
			// WebKit loads this request in the web view returned from `createWebViewWith`.
			// Allowing it here does not navigate the login page. Loading it here would.
			trace(navigationSummary("present popup", action: navigationAction, webView: webView))
			decisionHandler(.allow)
		case .allow:
			decisionHandler(.allow)
		}
	}

	/// WebKit loads `navigationAction` in the returned web view and sets `window.opener`
	/// to the login page. The view must be created with `configuration`.
	open func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		let decision = OAuth2EmbeddedNavigationPolicy.decide(
			url: navigationAction.request.url,
			targetFrameIsNil: true,
			intercept: interceptComponents
		)
		switch decision {
		case .intercept:
			trace(navigationSummary("createWebView redirect", action: navigationAction, webView: webView))
			if let url = navigationAction.request.url, let onIntercept = onIntercept {
				_ = interceptDecision(for: url, onIntercept: onIntercept)
			}
			return nil
		case .openExternally:
			trace(navigationSummary("createWebView external", action: navigationAction, webView: webView), level: SMARTServerLog.warn)
			if let url = navigationAction.request.url, claimPopup(url) {
				openExternally(url)
			}
			return nil
		case .presentPopup, .allow:
			trace(navigationSummary("createWebView popup", action: navigationAction, webView: webView))
			return makePopup(configuration: configuration, source: webView)
		}
	}

	open func webViewDidClose(_ webView: WKWebView) {
		guard let host = popups.first(where: { $0.popupWebView == webView }) else {
			return
		}
		closePopup(host, reason: "window.close")
	}

	private func makePopup(configuration: WKWebViewConfiguration, source: WKWebView) -> WKWebView {
		let popup = WKWebView(frame: source.bounds, configuration: configuration)
		popup.navigationDelegate = self
		popup.uiDelegate = self
		popup.allowsBackForwardNavigationGestures = true
		if let agent = source.customUserAgent {
			popup.customUserAgent = agent
		}
		let host = OAuth2PopupViewController(popupWebView: popup)
		host.onClose = { [weak self, weak host] in
			guard let self, let host else { return }
			self.closePopup(host, reason: "close-button")
		}
		popups.append(host)
		host.loadViewIfNeeded()
		if navigationController == nil {
			trace("popup not shown because the login web view has no navigation controller", level: SMARTServerLog.error)
		}
		navigationController?.pushViewController(host, animated: true)
		return popup
	}

	private func closePopup(_ host: OAuth2PopupViewController, reason: String) {
		trace("popup closed reason=\(reason) url=\(OAuth2EmbeddedNavigationPolicy.redacted(host.popupWebView.url))")
		host.popupWebView.stopLoading()
		popups.removeAll { $0 === host }
		guard let navigationController = navigationController else {
			return
		}
		if navigationController.topViewController === host {
			navigationController.popViewController(animated: true)
			return
		}
		var stack = navigationController.viewControllers
		stack.removeAll { $0 === host }
		navigationController.setViewControllers(stack, animated: true)
	}

	/// True when the redirect should be canceled. Calls `onIntercept` once per URL.
	private func interceptDecision(for url: URL, onIntercept: (URL) -> Bool) -> Bool {
		if let last = lastIntercept, last.url == url, Date().timeIntervalSince(last.at) < 1 {
			return last.cancel
		}
		let cancel = onIntercept(url)
		lastIntercept = (url, Date(), cancel)
		return cancel
	}

	/// True the first time `url` is handled within a short window. The second delegate
	/// call for the same custom scheme must not open the external app again.
	private func claimPopup(_ url: URL) -> Bool {
		if let last = lastHandledPopup, last.url == url, Date().timeIntervalSince(last.at) < 1 {
			return false
		}
		lastHandledPopup = (url, Date())
		return true
	}

	private func openExternally(_ url: URL) {
		#if !P2_APP_EXTENSIONS
		UIApplication.shared.open(url, options: [:], completionHandler: nil)
		#endif
	}

	private func trace(_ message: String, level: String = SMARTServerLog.info) {
		SMARTServerLog.log(message, level: level)
		oauth?.logger?.debug("OAuth2", msg: message)
	}

	private func navigationSummary(_ event: String, action: WKNavigationAction, webView: WKWebView) -> String {
		let source = webView == self.webView ? "login" : "popup"
		let target = action.targetFrame == nil ? "new-window" : "frame"
		return "\(event) source=\(source) target=\(target) kind=\(navigationKind(action)) url=\(OAuth2EmbeddedNavigationPolicy.redacted(action.request.url))"
	}

	private func navigationKind(_ action: WKNavigationAction) -> String {
		switch action.navigationType {
		case .linkActivated:
			return "link"
		case .formSubmitted:
			return "form"
		case .backForward:
			return "backForward"
		case .reload:
			return "reload"
		case .formResubmitted:
			return "formResubmitted"
		case .other:
			return "other"
		@unknown default:
			return "unknown"
		}
	}
	
	open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if "file" != webView.url?.scheme {
			showLoadingIndicator()
		}
	}
	
	open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if webView != self.webView {
			let title = webView.title ?? ""
			let safeTitle = title.hasPrefix("Success ") ? "redacted" : title
			trace("popup finished url=\(OAuth2EmbeddedNavigationPolicy.redacted(webView.url)) title=\(safeTitle)")
			if !title.isEmpty, !title.hasPrefix("Success "),
			   let host = popups.first(where: { $0.popupWebView == webView }) {
				host.title = title
			}
			return
		}
		if let scheme = interceptComponents?.scheme, "urn" == scheme {
			if let path = interceptComponents?.path, path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.title, title.hasPrefix("Success ") {
					oauth?.logger?.debug("OAuth2", msg: "Creating redirect URL from document.title")
					let qry = title.replacingOccurrences(of: "Success ", with: "")
					if let url = URL(string: "http://localhost/?\(qry)") {
						_ = onIntercept?(url)
						return
					}
					oauth?.logger?.warn("OAuth2", msg: "Failed to create a URL with query parts \"\(qry)\"")
				}
			}
		}
		hideLoadingIndicator()
		showHideBackButton(webView.canGoBack)
	}
	
	open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		if NSURLErrorDomain == error._domain && NSURLErrorCancelled == error._code {
			return
		}
		let source = webView == self.webView ? "login" : "popup"
		let nsError = error as NSError
		trace("navigation failed source=\(source) url=\(OAuth2EmbeddedNavigationPolicy.redacted(webView.url)) domain=\(nsError.domain) code=\(nsError.code)", level: SMARTServerLog.error)
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		if nil != loadingView {
			showErrorMessage(error.localizedDescription, animated: true)
		}
	}

	open func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		self.webView(webView, didFail: navigation, withError: error)
	}
}

/// A second browsing context pushed over the login page. Closing it returns to that
/// page; it does not cancel the OAuth session.
final class OAuth2PopupViewController: UIViewController {
	let popupWebView: WKWebView
	var onClose: (() -> Void)?

	init(popupWebView: WKWebView) {
		self.popupWebView = popupWebView
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let container = UIView()
		container.backgroundColor = .white
		popupWebView.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(popupWebView)
		NSLayoutConstraint.activate([
			popupWebView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			popupWebView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			popupWebView.topAnchor.constraint(equalTo: container.topAnchor),
			popupWebView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
		])
		view = container
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .close,
			target: self,
			action: #selector(close)
		)
	}

	@objc private func close() {
		onClose?()
	}
}

/// Swift < 4.2 support
#if !(swift(>=4.2))
private extension UIScrollView {
	enum DecelerationRate {
		static let normal = UIScrollViewDecelerationRateNormal
	}
}
#endif

#endif
