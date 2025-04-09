/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.brave.browser.customize_menu;

import android.content.Context;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.PopupMenu;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import org.chromium.base.Log;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

/**
 * Utility class for working with Brave's customize menu. Provides helper methods for accessing and
 * filtering menu items.
 */
public class CustomizeMenuUtils {

    private static final String TAG = "CustomizeMenuUtils";
    private static final String CUSTOMIZE_MENU_ITEMS = "customize_menu_items";

    public static void saveMenuItems(List<CustomMenuItem> menuItems) {
        if (menuItems == null) {
            return;
        }

        try {
            JSONArray jsonArray = new JSONArray();
            for (CustomMenuItem item : menuItems) {
                jsonArray.put(item.toJson());
            }
            ChromeSharedPreferences.getInstance()
                    .writeString(CUSTOMIZE_MENU_ITEMS, jsonArray.toString());
        } catch (Exception e) {
            Log.e(TAG, "Error saving search engines", e);
        }
    }

    public static List<CustomMenuItem> loadMenuItems() {
        String jsonString =
                ChromeSharedPreferences.getInstance().readString(CUSTOMIZE_MENU_ITEMS, null);
        if (jsonString == null) {
            return new LinkedList<>();
        }

        try {
            JSONArray jsonArray = new JSONArray(jsonString);
            List<CustomMenuItem> menuItems = new ArrayList<>();
            for (int i = 0; i < jsonArray.length(); i++) {
                JSONObject jsonObject = jsonArray.getJSONObject(i);
                CustomMenuItem item = CustomMenuItem.fromJson(jsonObject);
                if (item != null) {
                    menuItems.add(item);
                }
            }
            return menuItems;
        } catch (JSONException e) {
            Log.e(TAG, "Error loading menu items", e);
            return new LinkedList<>();
        }
    }

    /**
     * Gets a list of menu items belonging to a specific group ID.
     *
     * @param context Android context needed to create PopupMenu
     * @param groupId The group ID to filter menu items by
     * @return List of MenuItem objects that belong to the specified group
     */
    public static List<MenuItem> getMenuItemsByGroup(Context context, int groupId) {
        List<MenuItem> filteredItems = new ArrayList<>();
        Menu menu = createPopupMenu(context);

        for (int i = 0; i < menu.size(); i++) {
            MenuItem menuItem = menu.getItem(i);
            if (menuItem.getGroupId() == groupId) {
                logMenuItemDetails(menuItem);
                filteredItems.add(menuItem);
            }
        }

        return filteredItems;
    }

    /** Creates and initializes a PopupMenu with the brave_main_menu inflated. */
    private static Menu createPopupMenu(Context context) {
        PopupMenu popupMenu = new PopupMenu(context, null);
        Menu menu = popupMenu.getMenu();
        popupMenu.getMenuInflater().inflate(R.menu.brave_main_menu, menu);
        return menu;
    }

    /** Logs details about a menu item for debugging purposes. */
    private static void logMenuItemDetails(MenuItem menuItem) {
        Log.e(TAG, "Menu item: " + menuItem.getTitle());
        Log.e(TAG, "Menu item: " + menuItem.getItemId());
    }
}
