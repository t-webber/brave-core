/* Copyright (c) 2024 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "chrome/browser/ui/test/test_browser_dialog.h"
#include "chrome/browser/ui/test/test_browser_ui.h"

// On CI, the dialog shows out of bounds of the screen for some reason:
// [test_browser_dialog.cc(155)] VerifyUi(): Dialog bounds -290,74 334x244
// outside of display work area 0,0 1280x800
#define ShowAndVerifyUi()                 \
  set_should_verify_dialog_bounds(false); \
  ShowAndVerifyUi()

#include "src/chrome/browser/ui/views/extensions/dialogs/mv2_deprecation_keep_dialog_browsertest.cc"
#undef ShowAndVerifyUi
