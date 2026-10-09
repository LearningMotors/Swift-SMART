//
//  SMARTServerLog.swift
//  OAuth2
//
//  Embedded authorize events are forwarded to the host app, which sends them with the
//  same /log-message request the iOS client uses (sendLogToServer). The SDK does not
//  hold the session token or the API host.
//

import Foundation


public enum SMARTServerLog {
	public static let info = "info"
	public static let warn = "warn"
	public static let error = "error"

	/// Set by the iOS app to `BackendLogger.log`, which posts `sendLogToServer`.
	public static var sender: ((String, String) -> Void)?

	public static func log(_ message: String, level: String = SMARTServerLog.info) {
		sender?(message, level)
	}
}
