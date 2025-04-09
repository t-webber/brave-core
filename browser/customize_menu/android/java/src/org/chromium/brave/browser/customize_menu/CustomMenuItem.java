/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.brave.browser.customize_menu;

import android.view.MenuItem;

import org.json.JSONException;
import org.json.JSONObject;

import org.chromium.base.Log;

public class CustomMenuItem {

    private static final String TAG = "CustomMenuItem";

    private int itemId;
    private String title;
    private boolean shouldShow;

    public CustomMenuItem(MenuItem item) {
        this.itemId = item.getItemId();
        this.title = item.getTitle() != null ? item.getTitle().toString() : "";
        this.shouldShow = true;
    }

    public CustomMenuItem(int itemId, String title, boolean shouldShow) {
        this.itemId = itemId;
        this.title = title;
        this.shouldShow = shouldShow;
    }

    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("itemId", itemId);
            json.put("title", title);
            if (itemId == R.id.brave_rewards_id) {
                json.put("shouldShow", false);
            } else {
                json.put("shouldShow", shouldShow);
            }
        } catch (JSONException e) {
            Log.e(TAG, "Error converting MenuItem to JSON", e);
        }
        Log.e(TAG, "MenuItem to JSON: " + json.toString());
        return json;
    }

    public static CustomMenuItem fromJson(JSONObject json) {
        try {
            int itemId = json.getInt("itemId");
            String title = json.getString("title");
            boolean shouldShow = json.getBoolean("shouldShow");
            return new CustomMenuItem(itemId, title, shouldShow);
        } catch (JSONException e) {
            Log.e(TAG, "Error converting JSON to MenuItem", e);
            return null;
        }
    }

    public CustomMenuItem fromJsonString(String jsonString) throws JSONException {
        return fromJson(new JSONObject(jsonString));
    }

    public int getItemId() {
        return itemId;
    }

    public String getTitle() {
        return title;
    }

    public boolean shouldShow() {
        return shouldShow;
    }
}
