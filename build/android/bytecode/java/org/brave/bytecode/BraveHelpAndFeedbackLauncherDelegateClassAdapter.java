/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.brave.bytecode;

import org.objectweb.asm.ClassVisitor;

public class BraveHelpAndFeedbackLauncherDelegateClassAdapter extends BraveClassVisitor {
    static String sHelpAndFeedbackLauncherDelegateClassName =
        "org/chromium/chrome/browser/feedback/HelpAndFeedbackLauncherDelegate";

    static String sBraveHelpAndFeedbackLauncherDelegateClassName =
        "org/chromium/chrome/browser/feedback/BraveHelpAndFeedbackLauncherDelegate";

    static String sLaunchFallbackSupportUri = "launchFallbackSupportUri";

    public BraveHelpAndFeedbackLauncherDelegateClassAdapter(ClassVisitor visitor) {
        super(visitor);
        changeMethodOwner(sHelpAndFeedbackLauncherDelegateClassName, sLaunchFallbackSupportUri,
                          sBraveHelpAndFeedbackLauncherDelegateClassName);
    }
}
