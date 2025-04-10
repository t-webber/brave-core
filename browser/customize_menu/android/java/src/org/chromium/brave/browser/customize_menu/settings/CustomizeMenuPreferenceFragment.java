/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */
package org.chromium.brave.browser.customize_menu.settings;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import org.chromium.base.supplier.ObservableSupplier;
import org.chromium.base.supplier.ObservableSupplierImpl;
import org.chromium.brave.browser.customize_menu.CustomizeMenuUtils;
import org.chromium.brave.browser.customize_menu.R;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;
import org.chromium.chrome.browser.settings.ChromeBaseSettingsFragment;

public class CustomizeMenuPreferenceFragment extends ChromeBaseSettingsFragment
        implements CustomizeMenuListener {
    private static final String TAG = "CustomizeMenuPreferenceFragment";
    private RecyclerView mRecyclerView;

    private final ObservableSupplierImpl<String> mPageTitle = new ObservableSupplierImpl<>();

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mPageTitle.set(getString(R.string.customize_menu_title));
    }

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {}

    @Override
    public View onCreateView(
            @NonNull LayoutInflater inflater,
            @Nullable ViewGroup container,
            @Nullable Bundle savedInstanceState) {
        return setupView(
                inflater.inflate(R.layout.customize_menu_preference_layout, container, false));
    }

    private View setupView(View view) {
        mRecyclerView = view.findViewById(R.id.custom_menu_item_list);
        mRecyclerView.setLayoutManager(new LinearLayoutManager(getContext()));

        CustomizeMenuAdapter adapter = new CustomizeMenuAdapter();
        adapter.setCustomizeMenuListener(this);
        adapter.submitList(CustomizeMenuUtils.getMenuItemsByGroup(getActivity(), R.id.PAGE_MENU));
        mRecyclerView.setAdapter(adapter);
        return view;
    }

    @Override
    public void onMenuItemSelected(MenuItem menuItem, boolean isShown) {
        ChromeSharedPreferences.getInstance()
                .writeBoolean(String.valueOf(menuItem.getItemId()), isShown);
    }

    @Override
    public ObservableSupplier<String> getPageTitle() {
        return mPageTitle;
    }
}
