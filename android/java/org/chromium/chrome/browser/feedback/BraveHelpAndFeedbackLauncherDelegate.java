// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.feedback;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.provider.Browser;
import org.chromium.base.Log;

import androidx.annotation.NonNull;

/** Delegate that handles the display of the HelpAndFeedback flows. */
public class BraveHelpAndFeedbackLauncherDelegate {
    static final String FALLBACK_SUPPORT_URL = "https://community.brave.com/";

    public static void launchFallbackSupportUri(Context context) {
        Log.e("brave_help", "BraveHelpAndFeedbackLauncherDelegate : launchFallbackSupportUri");
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(FALLBACK_SUPPORT_URL));
        // Let Chrome know that this intent is from Chrome, so that it does not close the app when
        // the user presses 'back' button.
        intent.putExtra(Browser.EXTRA_APPLICATION_ID, context.getPackageName());
        intent.putExtra(Browser.EXTRA_CREATE_NEW_TAB, true);
        intent.setPackage(context.getPackageName());
        context.startActivity(intent);
    }
}
