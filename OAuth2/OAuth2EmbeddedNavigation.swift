//
//  OAuth2EmbeddedNavigation.swift
//  OAuth2
//
//  Decides how the embedded authorize web view treats a navigation.
//  Epic Hyperspace "Log in with Authenticator" opens a second window (window.open /
//  target=_blank). That window must stay a separate web view: Epic finishes 2FA by
//  scripting window.opener on the original login page. Loading the popup in the
//  login page replaces that page and leaves a blank document.
//

import Foundation


enum OAuth2EmbeddedNavigation: Equatable {
	case intercept
	case openExternally
	/// `window.open` / `target=_blank`. WebKit loads this in the web view returned from
	/// `createWebViewWith`. The login page must not navigate to it.
	case presentPopup
	case allow
}


enum OAuth2EmbeddedNavigationPolicy {

	/// - parameter targetFrameIsNil: True when WebKit has no frame for this navigation
	///   (`window.open`, `target=_blank`).
	static func decide(url: URL?, targetFrameIsNil: Bool, intercept: URLComponents?) -> OAuth2EmbeddedNavigation {
		guard let url = url else {
			// `window.open()` with no URL yet. The new browsing context has to exist
			// so the page can set its location afterwards.
			return targetFrameIsNil ? .presentPopup : .allow
		}
		if matchesIntercept(url, intercept: intercept) {
			return .intercept
		}
		if shouldOpenExternally(url) {
			return .openExternally
		}
		if targetFrameIsNil && shouldPresentAsPopup(url) {
			return .presentPopup
		}
		return .allow
	}

	/// Same scheme, host, and path check the web view used before popup handling.
	static func matchesIntercept(_ url: URL, intercept: URLComponents?) -> Bool {
		guard let intercept = intercept else {
			return false
		}
		guard url.scheme == intercept.scheme && url.host == intercept.host else {
			return false
		}
		let hp = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path ?? ""
		let ip = intercept.path
		return hp == ip || ("/" == hp + ip)
	}

	static func isWebURL(_ url: URL) -> Bool {
		guard let scheme = url.scheme?.lowercased() else {
			return false
		}
		return scheme == "http" || scheme == "https"
	}

	/// Documents that belong in a second window. `about:blank` is the usual `window.open()` result.
	static func shouldPresentAsPopup(_ url: URL) -> Bool {
		if isWebURL(url) {
			return true
		}
		switch url.scheme?.lowercased() {
		case "about", "blob", "data":
			return true
		default:
			return false
		}
	}

	/// Custom URL schemes (authenticator apps). Web and in-page schemes stay in the web view.
	static func shouldOpenExternally(_ url: URL) -> Bool {
		guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
			return false
		}
		switch scheme {
		case "http", "https", "about", "file", "blob", "data", "javascript":
			return false
		default:
			return true
		}
	}
}
