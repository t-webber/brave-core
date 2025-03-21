// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import BraveCore
import BraveShields
import BraveUI
import BraveWallet
import CertificateUtilities
import Combine
import Data
import Favicon
import Foundation
import Preferences
import Shared
import Storage
import SwiftyJSON
import UserAgent
import Web
import WebKit
import os.log

protocol TabContentScriptLoader {
  static func loadUserScript(named: String) -> String?
  static func secureScript(handlerName: String, securityToken: String, script: String) -> String
  static func secureScript(
    handlerNamesMap: [String: String],
    securityToken: String,
    script: String
  ) -> String
}

protocol TabContentScript: TabContentScriptLoader {
  static var scriptName: String { get }
  static var scriptId: String { get }
  static var messageHandlerName: String { get }
  static var scriptSandbox: WKContentWorld { get }
  static var userScript: WKUserScript? { get }

  func verifyMessage(message: WKScriptMessage) -> Bool
  func verifyMessage(message: WKScriptMessage, securityToken: String) -> Bool

  @MainActor func tab(
    _ tab: Tab,
    receivedScriptMessage message: WKScriptMessage,
    replyHandler: @escaping (Any?, String?) -> Void
  )
}

struct RewardsTabChangeReportingState {
  /// Set to true when the resulting page was restored from session state.
  var wasRestored = false
  /// Set to true when the resulting page navigation is not a reload or a
  /// back/forward type.
  var isNewNavigation = true
  /// HTTP status code of the resulting page.
  var httpStatusCode = -1
}

extension SecureContentState {
  var shouldDisplayWarning: Bool {
    switch self {
    case .unknown, .invalidCertificate, .missingSSL, .mixedContent:
      return true
    case .localhost, .secure:
      return false
    }
  }
}

extension Tab {
  var isDesktopSite: Bool {
    currentUserAgentType == .desktop
  }

  var containsWebPage: Bool {
    if let url = visibleURL {
      let isHomeURL = InternalURL(url)?.isAboutHomeURL
      return url.isWebPage() && isHomeURL != true
    }

    return false
  }

  var displayTitle: String {
    if let displayTabTitle = fetchDisplayTitle(using: visibleURL, title: title) {
      return displayTabTitle
    }

    // When picking a display title. Tabs with sessionData are pending a restore so show their old title.
    // To prevent flickering of the display title. If a tab is restoring make sure to use its lastTitle.
    if let url = self.visibleURL, InternalURL(url)?.isAboutHomeURL ?? false, !isRestoring {
      return Strings.Hotkey.newTabTitle
    }

    if let url = self.visibleURL, !InternalURL.isValid(url: url),
      let shownUrl = url.displayURL?.absoluteString, isWebViewCreated
    {
      return shownUrl
    }

    guard let lastTitle = self.lastTitle, !lastTitle.isEmpty else {
      // FF uses url?.displayURL?.absoluteString ??  ""
      if let title = visibleURL?.absoluteString {
        return title
      } else if let tab = SessionTab.from(tabId: id) {
        if tab.title.isEmpty {
          return Strings.Hotkey.newTabTitle
        }
        return tab.title
      }

      return ""
    }

    return lastTitle
  }

  /// This property is for fetching the actual URL for the Tab
  /// In private browsing the URL is in memory but this is not the case for normal mode
  /// For Normal  Mode Tab information is fetched using Tab ID from
  var fetchedURL: URL? {
    if isPrivate {
      if let url = visibleURL, url.isWebPage() {
        return url
      }
    } else {
      if let tabUrl = visibleURL, tabUrl.isWebPage() {
        return tabUrl
      } else if let fetchedTab = SessionTab.from(tabId: id), fetchedTab.url?.isWebPage() == true {
        return visibleURL
      }
    }

    return nil
  }

  // FIXME: This function makes no sense, remove
  func fetchDisplayTitle(using url: URL?, title: String?) -> String? {
    if let tabTitle = title, !tabTitle.isEmpty {
      var displayTitle = tabTitle

      // Checking host is "localhost" || host == "127.0.0.1"
      // or hostless URL (iOS forwards hostless URLs (e.g., http://:6571) to localhost.)
      // DisplayURL will retrieve original URL even it is redirected to Error Page
      if let isLocal = url?.displayURL?.isLocal, isLocal {
        displayTitle = ""
      }

      return displayTitle
    }

    return nil
  }

  func hideContent(_ animated: Bool = false) {
    view.isUserInteractionEnabled = false
    if animated {
      UIView.animate(
        withDuration: 0.25,
        animations: { () -> Void in
          self.view.alpha = 0.0
        }
      )
    } else {
      view.alpha = 0.0
    }
  }

  func showContent(_ animated: Bool = false) {
    view.isUserInteractionEnabled = true
    if animated {
      UIView.animate(
        withDuration: 0.25,
        animations: { () -> Void in
          self.view.alpha = 1.0
        }
      )
    } else {
      view.alpha = 1.0
    }
  }

  var displayFavicon: Favicon? {
    if let url = visibleURL, InternalURL(url)?.isAboutHomeURL == true {
      return Favicon(
        image: UIImage(sharedNamed: "brave.logo"),
        isMonogramImage: false,
        backgroundColor: .clear
      )
    }
    return favicon
  }

  func isDescendentOf(_ ancestor: Tab) -> Bool {
    return sequence(first: opener) { $0?.opener }.contains { $0 === ancestor }
  }
}

// MARK: - Brave Search

extension Tab {
  /// Call the api on the Brave Search website and passes the fallback results to it.
  /// Important: This method is also called when there is no fallback results
  /// or when the fallback call should not happen at all.
  /// The website expects the iOS device to always call this method(blocks on it).
  func injectResults() {
    Task { @MainActor in
      // If the backup search results happen before the Brave Search loads
      // The method we pass data to is undefined.
      // For such case we do not call that method or remove the search backup manager.

      do {
        let result = try await self.evaluateJavaScript(
          functionName: "window.onFetchedBackupResults === undefined",
          contentWorld: .page,
          escapeArgs: false,
          asFunction: false
        )
        guard let methodUndefined = result as? Bool else {
          Logger.module.error(
            "onFetchedBackupResults existence check, failed to unwrap bool result value"
          )
          return
        }

        if methodUndefined {
          Logger.module.info("Search Backup results are ready but the page has not been loaded yet")
          return
        }

        var queryResult = "null"

        if let url = self.visibleURL,
          BraveSearchManager.isValidURL(url),
          let result = self.braveSearchManager?.fallbackQueryResult
        {
          queryResult = result
        }

        defer {
          // Cleanup
          self.braveSearchManager = nil
        }

        try await self.evaluateJavaScript(
          functionName: "window.onFetchedBackupResults",
          args: [queryResult],
          contentWorld: BraveSearchScriptHandler.scriptSandbox,
          escapeArgs: false
        )
      } catch {
        Logger.module.error(
          "onFetchedBackupResults existence check error: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}

// MARK: - Brave SKU
extension Tab {
  func injectLocalStorageItem(key: String, value: String) {
    Task {
      try await self.evaluateJavaScript(
        functionName: "localStorage.setItem",
        args: [key, value],
        contentWorld: BraveSkusScriptHandler.scriptSandbox
      )
    }
  }
}

protocol TabHelper {
  init(tab: Tab)
  static var keyPath: WritableKeyPath<TabDataValues, Self?> { get }
  static func create(for tab: Tab)
  static func remove(from tab: Tab)
  static func from(tab: Tab) -> Self?
}

extension TabHelper {
  static func create(for tab: Tab) {
    if tab.data[keyPath: keyPath] == nil {
      tab.data[keyPath: keyPath] = Self(tab: tab)
    }
  }
  static func remove(from tab: Tab) {
    tab.data[keyPath: keyPath] = nil
  }
  static func from(tab: Tab) -> Self? {
    tab.data[keyPath: keyPath]
  }
}
