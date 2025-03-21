// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import BraveCore
import FaviconModels
import Foundation
import UIKit
import WebKit

// Left to do:
// - Handle UA changes somehow
// - Figure out visibleURL implementation for WebKitTab, see if we need virtualURL or initial url at creation
// - Figure out if there's any way to deal with redirects from CWVWebView for chain building
// - Chromium Tab implementations for KVO, etc
// - Figure out `reset`-style calls and how that would work with CWVWebView
// - Figure out how to expose cookie store
// - Move refresh control logic to UI side
// - Fix createNewTabWithRequest to be able to handle Chromium tabs somehow
// - Support however we were using webView.url now that we only have visibleURL (look for visibleURL in non-Web target)

// Todo later:
// - Move favicon fetching logic into Web
// - Remove TabEventHandler
// - Wrap WKUserContentController & JS related APIs

public enum UserAgentType {
  case none
  case automatic
  case mobile
  case desktop
}

public enum SecureContentState {
  case unknown
  case localhost
  case secure
  case invalidCertificate
  case missingSSL
  case mixedContent
}

public class TabFactory {
  public struct CreateTabParams {
    public var id: UUID
    public var configurationProvider: () -> WKWebViewConfiguration
    public var braveCore: BraveCoreMain?

    public init(
      id: UUID = .init(),
      configurationProvider: @escaping () -> WKWebViewConfiguration = { .init() },
      braveCore: BraveCoreMain?
    ) {
      self.id = id
      self.configurationProvider = configurationProvider
      self.braveCore = braveCore
    }
  }

  public static func create(with params: CreateTabParams) -> any Tab {
    let wkConfiguration = params.configurationProvider()
    wkConfiguration.enablePageTopColorSampling()
    if let braveCore = params.braveCore, FeatureList.kUseChromiumWebViews.enabled {
      let cwvConfiuration =
        wkConfiguration.websiteDataStore.isPersistent
        ? braveCore.defaultWebViewConfiguration
        : braveCore.nonPersistentWebViewConfiguration
      return ChromiumTab(
        id: params.id,
        configuration: cwvConfiuration,
        wkConfiguration: wkConfiguration
      )
    }
    return WebKitTab(id: params.id, configuration: wkConfiguration)
  }
}

@dynamicMemberLookup
public protocol Tab: AnyObject {
  typealias ID = UUID
  var id: ID { get }
  var isPrivate: Bool { get }
  var data: TabDataValues { get set }
  var view: UIView { get }
  var opener: (any Tab)? { get set }
  var isVisible: Bool { get set }
  var lastActiveTime: Date? { get }

  var webViewProxy: WebViewProxy? { get }
  var isWebViewCreated: Bool { get }
  func createWebView()
  func deleteWebView()

  // MARK: -
  var delegate: TabDelegate? { get set }
  var downloadDelegate: TabDownloadDelegate? { get set }
  func addPolicyDecider(_ policyDecider: some TabPolicyDecider)
  func removePolicyDecider(_ policyDecider: some TabPolicyDecider)
  func addObserver(_ observer: some TabObserver)
  func removeObserver(_ observer: some TabObserver)

  // MARK: - Current Page Data
  var visibleSecureContentState: SecureContentState { get }
  var serverTrust: SecTrust? { get }
  var favicon: Favicon? { get set }  // FIXME: Should be get only, make favicon fetch logic internal
  var visibleURL: URL? { get }
  var lastCommittedURL: URL? { get }
  var previousCommittedURL: URL? { get }
  var contentsMimeType: String? { get }
  var title: String? { get }
  var isLoading: Bool { get }
  var estimatedProgress: Double { get }
  var sessionData: Data? { get }
  func restore(using sessionData: Data)
  var canGoBack: Bool { get }
  var canGoForward: Bool { get }
  var backForwardList: (any BackForwardListProxy)? { get }
  // Remove when CWVBackFowardListItem exposes original request URL
  var currentInitialURL: URL? { get }
  var isRestoring: Bool { get }
  var currentUserAgentType: UserAgentType { get }

  // MARK: -
  func loadRequest(_ request: URLRequest)
  func setVirtualURL(_ url: URL?)
  func reload()
  func reloadWithUserAgentType(_ userAgentType: UserAgentType)
  func stopLoading()
  func goBack()
  func goForward()
  func goToBackForwardListItem(_ item: any BackForwardListItemProxy)
  var canTakeSnapshot: Bool { get }
  func takeSnapshot(rect: CGRect) async -> UIImage?
  func createFullPagePDF() async throws -> Data?
  func presentFindInteraction(with text: String)
  func dismissFindInteraction()
  func evaluateJavaScriptUnsafe(_ javascript: String)

  // MARK: - WebKit specific
  // These APIs require the use of WKWebView and its associated APIs as there are no WebState
  // alternatives for them or require the use of private API
  func loadHTMLString(_ htmlString: String, baseURL: URL?)
  @discardableResult
  func evaluateJavaScript(
    functionName: String,
    args: [Any],
    frame: WKFrameInfo?,
    contentWorld: WKContentWorld,
    escapeArgs: Bool,
    asFunction: Bool
  ) async throws -> Any?
  @discardableResult
  func callAsyncJavaScript(
    _ functionBody: String,
    arguments: [String: Any],
    in frame: WKFrameInfo?,
    contentWorld: WKContentWorld
  ) async throws -> Any?
  var configuration: WKWebViewConfiguration { get }
  var viewPrintFormatter: UIViewPrintFormatter? { get }
  var dataForDisplayedPDF: Data? { get }
  var sampledPageTopColor: UIColor? { get }
  var viewScale: CGFloat { get set }
  func clearBackForwardList()
}

extension Tab {
  public func switchUserAgent() {
    reloadWithUserAgentType(currentUserAgentType == .mobile ? .desktop : .mobile)
  }

  public subscript<Value>(dynamicMember member: KeyPath<TabDataValues, Value>) -> Value {
    return data[keyPath: member]
  }

  public subscript<Value>(dynamicMember member: WritableKeyPath<TabDataValues, Value>) -> Value {
    get { return data[keyPath: member] }
    set { data[keyPath: member] = newValue }
  }
}

// Default args for methods
extension Tab {
  public func presentFindInteraction() {
    presentFindInteraction(with: "")
  }

  @discardableResult
  public func evaluateJavaScript(
    functionName: String,
    args: [Any] = [],
    frame: WKFrameInfo? = nil,
    contentWorld: WKContentWorld,
    escapeArgs: Bool = true,
    asFunction: Bool = true
  ) async throws -> Any? {
    try await evaluateJavaScript(
      functionName: functionName,
      args: args,
      frame: frame,
      contentWorld: contentWorld,
      escapeArgs: escapeArgs,
      asFunction: asFunction
    )
  }

  public func evaluateJavaScript(
    functionName: String,
    args: [Any] = [],
    frame: WKFrameInfo? = nil,
    contentWorld: WKContentWorld,
    escapeArgs: Bool = true,
    asFunction: Bool = true,
    completionHandler: ((Any?, Error?) -> Void)? = nil
  ) {
    Task {
      do {
        let result = try await evaluateJavaScript(
          functionName: functionName,
          args: args,
          frame: frame,
          contentWorld: contentWorld,
          escapeArgs: escapeArgs,
          asFunction: asFunction
        )
        completionHandler?(result, nil)
      } catch {
        completionHandler?(nil, error)
      }
    }
  }

  @discardableResult
  public func callAsyncJavaScript(
    _ functionBody: String,
    arguments: [String: Any] = [:],
    in frame: WKFrameInfo? = nil,
    contentWorld: WKContentWorld
  ) async throws -> Any? {
    try await callAsyncJavaScript(
      functionBody,
      arguments: arguments,
      in: frame,
      contentWorld: contentWorld
    )
  }
}

public protocol WebViewProxy {
  var scrollView: UIScrollView? { get }
  var bounds: CGRect { get }
  var frame: CGRect { get }
  func becomeFirstResponder() -> Bool
}

public protocol BackForwardListProxy {
  var backList: [any BackForwardListItemProxy] { get }
  var forwardList: [any BackForwardListItemProxy] { get }
  var currentItem: (any BackForwardListItemProxy)? { get }
  var backItem: (any BackForwardListItemProxy)? { get }
  var forwardItem: (any BackForwardListItemProxy)? { get }
}

public protocol BackForwardListItemProxy: Equatable {
  var url: URL { get }
  var title: String? { get }
}

public struct TabDataValues {
  private var storage: [AnyHashable: Any] = [:]

  public subscript<Key: TabDataKey>(key: Key.Type) -> Key.Value {
    get {
      guard let helper = storage[ObjectIdentifier(key)] as? Key.Value else {
        return Key.defaultValue
      }
      return helper
    }
    set {
      storage[ObjectIdentifier(key)] = newValue
    }
  }
}

public protocol TabDataKey {
  associatedtype Value
  static var defaultValue: Value { get }
}
