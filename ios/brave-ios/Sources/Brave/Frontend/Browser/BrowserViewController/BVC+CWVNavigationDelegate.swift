// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import BraveCore
import BraveShared
import Data

@MainActor
class ChromiumNavigationDelegateAdapter: NSObject, @preconcurrency BraveWebViewNavigationDelegate {
  private weak var tab: Tab?

  init(tab: Tab) {
    self.tab = tab
  }

  public func webView(
    _ webView: CWVWebView,
    shouldBlockJavaScriptFor request: URLRequest
  ) -> Bool {
    guard let tab, let delegate = tab.webDelegate else { return false }
    return delegate.tab(tab, shouldBlockJavaScriptForRequest: request)
  }

  public func webView(
    _ webView: CWVWebView,
    shouldBlockUniversalLinksFor request: URLRequest
  ) -> Bool {
    guard let tab, let delegate = tab.webDelegate else { return false }
    return delegate.tab(tab, shouldBlockUniversalLinksForRequest: request)
  }

  public func webView(
    _ webView: CWVWebView,
    didRequestHTTPAuthFor protectionSpace: URLProtectionSpace,
    proposedCredential: URLCredential,
    completionHandler handler: @escaping (String?, String?) -> Void
  ) {
    Task {
      guard let tab, let delegate = tab.webDelegate else {
        handler(nil, nil)
        return
      }
      let resolvedCredential = await delegate.tab(
        tab,
        didRequestHTTPAuthFor: protectionSpace,
        proposedCredential: proposedCredential,
        previousFailureCount: 0
      )
      handler(resolvedCredential?.user, resolvedCredential?.password)
    }
  }

  public func webViewDidStartNavigation(_ webView: CWVWebView) {
    guard let tab else { return }
    tab.didStartNavigation()
  }

  public func webView(
    _ webView: CWVWebView,
    decidePolicyFor navigationAction: CWVNavigationAction,
    decisionHandler: @escaping (CWVNavigationActionPolicy) -> Void
  ) {
    guard let tab else { return }
    let navigationType: WebNavigationType = {
      if navigationAction.navigationType.contains(.forwardBack) {
        return .backForward
      }
      switch navigationAction.navigationType.coreType {
      case .link:
        return .linkActivated
      case .reload:
        return .reload
      case .formSubmit:
        return .formSubmitted
      default:
        return .other
      }
    }()

    Task { @MainActor in
      // Setup braveSearchManager on the tab as it requires accessing WKWebView cookies
      if let url = navigationAction.request.url,
        navigationAction.navigationType.isMainFrame, BraveSearchManager.isValidURL(url)
      {
        // We fetch cookies to determine if backup search was enabled on the website.
        //      let profile = self.profile
        let cookies = await webView.wkConfiguration.websiteDataStore.httpCookieStore.allCookies()
        tab.braveSearchManager = BraveSearchManager(
          url: url,
          cookies: cookies
        )
      } else {
        tab.braveSearchManager = nil
      }

      let policy = await tab.shouldAllowRequest(
        navigationAction.request,
        requestInfo: .init(
          navigationType: navigationType,
          isMainFrame: navigationAction.navigationType.isMainFrame,
          isNewWindow: navigationAction.navigationType == .newWindow,
          isUserInitiated: navigationAction.isUserInitiated
        )
      )
      decisionHandler(policy == .allow ? .allow : .cancel)
    }
  }

  public func webViewDidCommitNavigation(_ webView: CWVWebView) {
    guard let tab else { return }
    // Set the committed url which will also set tab.url
    tab.committedURL = webView.lastCommittedURL
    tab.didCommitNavigation()
  }

  public func webView(
    _ webView: CWVWebView,
    decidePolicyFor navigationResponse: CWVNavigationResponse,
    decisionHandler: @escaping (CWVNavigationResponsePolicy) -> Void
  ) {
    guard let tab else { return }
    Task { @MainActor in
      let policy = await tab.shouldAllowResponse(
        navigationResponse.response,
        responseInfo: .init(isForMainFrame: navigationResponse.isForMainFrame)
      )
      decisionHandler(policy == .allow ? .allow : .cancel)
    }
  }

  public func webViewDidFinishNavigation(_ webView: CWVWebView) {
    guard let tab else { return }
    tab.didFinishNavigation()
  }

  public func webView(_ webView: CWVWebView, didFailNavigationWithError error: any Error) {
    guard let tab else { return }
    tab.didFailNavigation(with: error)
  }

  public func webView(_ webView: CWVWebView, didRequestDownloadWith task: CWVDownloadTask) {
    guard let tab else { return }
    let pendingDownload = ChromiumDownload(
      downloadTask: task,
      didFinish: { [weak self, weak tab] download, error in
        guard let self, let tab else { return }
        tab.downloadDelegate?.tab(tab, didFinishDownload: download, error: error)
      }
    )
    tab.downloadDelegate?.tab(tab, didCreateDownload: pendingDownload)
  }
}

@MainActor
class ChromiumUIDelegateAdapter: NSObject, @preconcurrency CWVUIDelegate {
  private weak var tab: Tab?

  init(tab: Tab) {
    self.tab = tab
  }

  func webView(
    _ webView: CWVWebView,
    createWebViewWith configuration: CWVWebViewConfiguration,
    for action: CWVNavigationAction
  ) -> CWVWebView? {
    guard let tab else { return nil }

    guard !action.request.isInternalUnprivileged,
      let navigationURL = action.request.url,
      navigationURL.shouldRequestBeOpenedAsPopup()
    else {
      print("Denying popup from request: \(action.request)")
      return nil
    }

    // FIXME: Add Tab creation when creating a Tab with a CWVWebView is available
    return nil
  }

  func webViewDidClose(_ webView: CWVWebView) {
    guard let tab else { return }
    tab.webDelegate?.tabWebViewDidClose(tab)
  }

  func webView(
    _ webView: CWVWebView,
    contextMenuConfigurationFor element: CWVHTMLElement,
    completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
  ) {
    guard let tab else {
      completionHandler(nil)
      return
    }
    Task {
      let configuration = await tab.webDelegate?.tab(
        tab,
        contextMenuConfigurationForLinkURL: element.hyperlink
      )
      completionHandler(configuration)
    }
  }

  func webView(
    _ webView: CWVWebView,
    requestMediaCapturePermissionFor type: CWVMediaCaptureType,
    decisionHandler: @escaping (CWVPermissionDecision) -> Void
  ) {
    guard let tab, let captureType = WebMediaCaptureType(type), let delegate = tab.webDelegate
    else {
      decisionHandler(.prompt)
      return
    }
    Task {
      let permission = await delegate.tab(tab, requestMediaCapturePermissionsFor: captureType)
      decisionHandler(.init(permission))
    }
  }

  func webView(
    _ webView: CWVWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    pageURL url: URL,
    completionHandler: @escaping () -> Void
  ) {
    guard let tab else {
      completionHandler()
      return
    }
    Task {
      await tab.webDelegate?.tab(tab, runJavaScriptAlertPanelWithMessage: message, pageURL: url)
      completionHandler()
    }
  }

  func webView(
    _ webView: CWVWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    pageURL url: URL,
    completionHandler: @escaping (Bool) -> Void
  ) {
    guard let tab, let delegate = tab.webDelegate else {
      completionHandler(false)
      return
    }
    Task {
      let result = await delegate.tab(
        tab,
        runJavaScriptConfirmPanelWithMessage: message,
        pageURL: url
      )
      completionHandler(result)
    }
  }

  func webView(
    _ webView: CWVWebView,
    runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String,
    pageURL url: URL,
    completionHandler: @escaping (String?) -> Void
  ) {
    guard let tab, let delegate = tab.webDelegate else {
      completionHandler(nil)
      return
    }
    Task {
      let result = await delegate.tab(
        tab,
        runJavaScriptConfirmPanelWithPrompt: prompt,
        defaultText: defaultText,
        pageURL: url
      )
      completionHandler(result)
    }
  }
}

extension WebMediaCaptureType {
  init?(_ mediaCaptureType: CWVMediaCaptureType) {
    switch mediaCaptureType {
    case .microphone:
      self = .microphone
    case .camera:
      self = .camera
    case .cameraAndMicrophone:
      self = .cameraAndMicrophone
    default:
      return nil
    }
  }
}

extension CWVPermissionDecision {
  init(_ decision: WebPermissionDecision) {
    switch decision {
    case .prompt:
      self = .prompt
    case .grant:
      self = .grant
    case .deny:
      self = .deny
    }
  }
}
