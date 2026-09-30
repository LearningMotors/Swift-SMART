//
//  OAuth2EmbeddedNavigationTests.swift
//

import XCTest
@testable import SMART


class OAuth2EmbeddedNavigationTests: XCTestCase {

	private let redirect = URLComponents(string: "suki://oauth/callback")

	func testOAuthRedirectIsInterceptedAheadOfExternalOpen() {
		let url = URL(string: "suki://oauth/callback?code=abc")!
		let decision = OAuth2EmbeddedNavigationPolicy.decide(url: url, targetFrameIsNil: true, intercept: redirect)
		XCTAssertEqual(decision, .intercept)
	}

	func testAuthenticatorPopupLoadsInTheCurrentWebView() {
		let url = URL(string: "https://epicproxy.example.com/authenticator")!
		let decision = OAuth2EmbeddedNavigationPolicy.decide(url: url, targetFrameIsNil: true, intercept: redirect)
		XCTAssertEqual(decision, .loadInCurrentWebView)
	}

	func testMainFrameWebNavigationIsAllowed() {
		let url = URL(string: "https://epicproxy.example.com/oauth2/authorize")!
		let decision = OAuth2EmbeddedNavigationPolicy.decide(url: url, targetFrameIsNil: false, intercept: redirect)
		XCTAssertEqual(decision, .allow)
	}

	func testCustomSchemeOpensExternallyWithoutDismissing() {
		let url = URL(string: "epic://authenticator/approve")!
		let decision = OAuth2EmbeddedNavigationPolicy.decide(url: url, targetFrameIsNil: false, intercept: redirect)
		XCTAssertEqual(decision, .openExternally)
	}

	func testAboutBlankStaysInTheWebView() {
		let url = URL(string: "about:blank")!
		let decision = OAuth2EmbeddedNavigationPolicy.decide(url: url, targetFrameIsNil: true, intercept: redirect)
		XCTAssertEqual(decision, .allow)
	}
}
