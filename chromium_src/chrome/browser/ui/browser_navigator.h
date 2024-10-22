/* Copyright (c) 2024 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#ifndef BRAVE_CHROMIUM_SRC_CHROME_BROWSER_UI_BROWSER_NAVIGATOR_H_
#define BRAVE_CHROMIUM_SRC_CHROME_BROWSER_UI_BROWSER_NAVIGATOR_H_

namespace content {
class BrowserContext;
}

// `IsURLAllowedInIncognito` used to take a profile argument, however this
// argument has been dropped as it has no use for chromium. Brave on the other
// hand needs the profile to determine if certain wallet URLs should be allowed
// in incognito mode. This override adds the argument back into it.
#define IsURLAllowedInIncognito(...)   \
  IsURLAllowedInIncognito(__VA_ARGS__, \
                          content::BrowserContext* browser_context = nullptr)

#include "src/chrome/browser/ui/browser_navigator.h"  // IWYU pragma: export

#undef IsURLAllowedInIncognito

#endif  // BRAVE_CHROMIUM_SRC_CHROME_BROWSER_UI_BROWSER_NAVIGATOR_H_
