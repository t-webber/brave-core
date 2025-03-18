/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.chrome.browser.ntp;

//import org.jni_zero.CalledByNative;

import org.chromium.base.Log;
import org.chromium.chrome.R;
import org.chromium.chrome.browser.app.BraveActivity;
import org.chromium.chrome.browser.infobar.BraveInfoBarIdentifier;
import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.ui.messages.infobar.BraveSimpleConfirmInfoBarBuilder;
import org.chromium.chrome.browser.ui.messages.infobar.SimpleConfirmInfoBarBuilder;
import org.chromium.chrome.browser.util.TabUtils;
import org.chromium.chrome.browser.preferences.BravePref;
import org.chromium.chrome.browser.profiles.Profile;
import org.chromium.components.prefs.PrefService;
import org.chromium.components.user_prefs.UserPrefs;

public class BraveNewTabTakeoverInfobar {
    private static final String TAG = "BraveNewTabTakeoverInfobar";
    private static final String LEARN_MORE_URL = "https://brave.com";

    public static void show(Profile profile) {
        try {
            PrefService prefService = UserPrefs.get(profile);
            // if (!prefService.getBoolean(BravePref.NEW_TAB_PAGE_SHOW_NEW_TAB_TAKEOVER_VIEWED_INFOBAR)) {
            //     return;
            // }
            prefService.setBoolean(BravePref.NEW_TAB_PAGE_SHOW_NEW_TAB_TAKEOVER_VIEWED_INFOBAR, false);

            BraveActivity activity = BraveActivity.getBraveActivity();
            Tab tab = activity.getActivityTabProvider().get();
            if (tab == null) return;

            BraveSimpleConfirmInfoBarBuilder.create(
                    tab.getWebContents(),
                    new SimpleConfirmInfoBarBuilder.Listener() {
                        @Override
                        public void onInfoBarDismissed() {}

                        @Override
                        public boolean onInfoBarButtonClicked(boolean isPrimary) {
                            return false;
                        }

                        @Override
                        public boolean onInfoBarLinkClicked() {
                            TabUtils.openUrlInSameTab(LEARN_MORE_URL);
                            return true;
                        }
                    },
                    BraveInfoBarIdentifier.NEW_TAB_TAKEOVER_VIEWED_INFOBAR_DELEGATE,
                    activity,
                    /*drawableId*/0,
                    activity.getString(R.string.new_tab_takeover_viewed_infobar_message, ""),
                    /*primaryText=*/"",
                    /*secondaryText=*/"",
                    activity.getString(R.string.new_tab_takeover_viewed_infobar_learn_more, ""),
                    /*autoExpire=*/true);
        } catch (BraveActivity.BraveActivityNotFoundException e) {
            Log.e(TAG, "show", e);
        }
    }
}
