//
//  OAuth2EmbeddedNavigation.swift
//  OAuth2
//
//  Decides how the embedded authorize web view treats a navigation.
//  Epic Hyperspace "Log in with Authenticator" opens a new window (window.open /
//  target=_blank) or a non-http scheme. The embedded WKWebView has a single frame,
//  so those navigations must be loaded in place or handed to the system — dismissing
//  the controller would cancel the OAuth session.
//

import Foundation


enum OAuth2EmbeddedNavigation: Equatable {
	case intercept
	case openExternally
	case loadInCurrentWebView
	case allow
}


enum OAuth2EmbeddedNavigationPolicy {

	/// - parameter targetFrameIsNil: True when WebKit has no frame for this navigation
	///   (`window.open`, `target=_blank`).
	static func decide(url: URL?, targetFrameIsNil: Bool, intercept: URLComponents?) -> OAuth2EmbeddedNavigation {
		guard let url = url else {
			return .allow
		}
		if matchesIntercept(url, intercept: intercept) {
			return .intercept
		}
		if shouldOpenExternally(url) {
			return .openExternally
		}
		if targetFrameIsNil && isWebURL(url) {
			return .loadInCurrentWebView
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
