// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

extension TabDataValues {
  private struct HTTPSUpgradesKey: TabDataKey {
    static var defaultValue: HTTPSUpgrades? = nil
  }
  var httpsUpgrades: HTTPSUpgrades? {
    get { self[HTTPSUpgradesKey.self] }
    set { self[HTTPSUpgradesKey.self] = newValue }
  }
}

/// Holds state related to HTTPS upgrades for the current navigation
struct HTTPSUpgrades {
  /// This is the request that was upgraded to HTTPS
  /// This allows us to rollback the upgrade when we encounter a 4xx+
  var request: URLRequest?
  /// This is a timer that's started on HTTPS upgrade
  /// If the upgrade hasn't completed within 3s, it is cancelled
  /// and we fallback to HTTP or cancel the request (strict vs. standard)
  var timeoutTimer: Timer?
}
