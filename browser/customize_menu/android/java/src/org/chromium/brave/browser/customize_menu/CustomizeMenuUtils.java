/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.brave.browser.customize_menu;

import android.content.Context;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import androidx.appcompat.content.res.AppCompatResources;
import androidx.appcompat.view.menu.MenuBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import org.chromium.base.Log;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;

/**
 * Utility class for working with Brave's customize menu. Provides helper methods for accessing and
 * filtering menu items.
 */
public class CustomizeMenuUtils {

    private static final String TAG = "CustomizeMenuUtils";
    private static final String CUSTOMIZE_MENU_ITEMS = "customize_menu_items";

    public static List<Integer> dividerIdList =
            new ArrayList<>(Arrays.asList(R.id.divider_line_id, R.id.managed_by_divider_line_id));

    private static List<Integer> exceptionIdList =
            new ArrayList<>(
                    Arrays.asList(
                            R.id.update_menu_id,
                            R.id.tinker_tank_menu_id,
                            R.id.icon_row_menu_id,
                            R.id.quick_delete_menu_id,
                            R.id.quick_delete_divider_line_id,
                            R.id.share_row_menu_id,
                            R.id.ai_web_menu_id,
                            R.id.ai_pdf_menu_id,
                            R.id.help_id,
                            R.id.preferences_id,
                            R.id.request_vpn_location_row_menu_id,
                            R.id.ntp_customization_id,
                            R.id.managed_by_divider_line_id,
                            R.id.managed_by_menu_id));

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
        MenuBuilder menu = new MenuBuilder(context);
        new MenuInflater(context).inflate(R.menu.brave_main_menu, menu);

        maybeReplaceIcons(context, menu);

        for (int i = 0; i < menu.size(); i++) {
            MenuItem menuItem = menu.getItem(i);
            if (menuItem.getGroupId() == groupId
                    && !exceptionIdList.contains(menuItem.getItemId())) {
                logMenuItemDetails(menuItem);
                filteredItems.add(menuItem);
            }
        }

        MenuItem braveNews = menu.add(Menu.NONE, R.id.brave_news_id, 0, R.string.brave_news_title);
        braveNews.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_news));
        filteredItems.add(braveNews);

        MenuItem rewards =
                menu.add(Menu.NONE, R.id.brave_rewards_id, 0, R.string.menu_brave_rewards);
        rewards.setIcon(AppCompatResources.getDrawable(context, R.drawable.brave_menu_rewards));
        filteredItems.add(rewards);

        MenuItem braveCustomizeMenu =
                menu.add(Menu.NONE, R.id.brave_customize_menu_id, 0, R.string.customize_menu_title);
        braveCustomizeMenu.setIcon(
                AppCompatResources.getDrawable(context, R.drawable.ic_window_screwdriver));
        filteredItems.add(braveCustomizeMenu);

        MenuItem exit = menu.add(Menu.NONE, R.id.exit_id, 0, R.string.menu_exit);
        exit.setIcon(AppCompatResources.getDrawable(context, R.drawable.brave_menu_exit));
        filteredItems.add(exit);

        return filteredItems;
    }

    private static void maybeReplaceIcons(Context context, Menu menu) {
        for (int i = 0; i < menu.size(); ++i) {
            MenuItem item = menu.getItem(i);
            if (item.getItemId() == R.id.new_tab_menu_id) {
                item.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_new_tab_page));
            } else if (item.getItemId() == R.id.new_incognito_tab_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(
                                context, R.drawable.brave_menu_new_private_tab));
            } else if (item.getItemId() == R.id.all_bookmarks_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.brave_menu_bookmarks));
            } else if (item.getItemId() == R.id.recent_tabs_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.brave_menu_recent_tabs));
            } else if (item.getItemId() == R.id.open_history_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.brave_menu_history));
            } else if (item.getItemId() == R.id.downloads_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.brave_menu_downloads));
            } else if (item.getItemId() == R.id.preferences_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.brave_menu_settings));
            } else if (item.getItemId() == R.id.brave_wallet_id) {
                item.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_crypto_wallets));
            } else if (item.getItemId() == R.id.brave_playlist_id) {
                item.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_open_playlist));
            } else if (item.getItemId() == R.id.add_to_playlist_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.ic_baseline_add_24));
            } else if (item.getItemId() == R.id.brave_leo_id) {
                item.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_brave_ai));
            } else if (item.getItemId() == R.id.request_desktop_site_row_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(context, R.drawable.ic_desktop_windows));
                item.setTitle(context.getString(R.string.menu_request_desktop_site));
            } else if (item.getItemId() == R.id.auto_dark_web_contents_row_menu_id) {
                item.setIcon(
                        AppCompatResources.getDrawable(
                                context, R.drawable.ic_brightness_medium_24dp));
                item.setTitle(context.getString(R.string.menu_auto_dark_web_contents));
            } else if (item.getItemId() == R.id.set_default_browser) {
                item.setIcon(
                        AppCompatResources.getDrawable(
                                context, R.drawable.brave_menu_set_as_default));
            } else if (item.getItemId() == R.id.request_brave_vpn_row_menu_id) {
                item.setIcon(AppCompatResources.getDrawable(context, R.drawable.ic_vpn));
                item.setTitle(context.getString(R.string.brave_vpn));
            }
        }
    }

    /** Logs details about a menu item for debugging purposes. */
    private static void logMenuItemDetails(MenuItem menuItem) {
        Log.e(TAG, "Menu item: " + menuItem.getTitle() + " ID: " + menuItem.getItemId());
    }
}
