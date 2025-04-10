/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.brave.browser.customize_menu.settings;

import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.materialswitch.MaterialSwitch;

import org.chromium.brave.browser.customize_menu.CustomizeMenuUtils;
import org.chromium.brave.browser.customize_menu.R;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;

public class CustomizeMenuAdapter extends ListAdapter<MenuItem, CustomizeMenuAdapter.ViewHolder> {
    private CustomizeMenuListener mCustomizeMenuListener;

    public CustomizeMenuAdapter() {
        super(DIFF_CALLBACK);
    }

    private static final DiffUtil.ItemCallback<MenuItem> DIFF_CALLBACK =
            new DiffUtil.ItemCallback<MenuItem>() {
                @Override
                public boolean areItemsTheSame(
                        @NonNull MenuItem oldItem, @NonNull MenuItem newItem) {
                    return oldItem.getItemId() == newItem.getItemId();
                }

                @Override
                public boolean areContentsTheSame(
                        @NonNull MenuItem oldItem, @NonNull MenuItem newItem) {
                    return oldItem.getItemId() == newItem.getItemId();
                }
            };

    public void setCustomizeMenuListener(CustomizeMenuListener customizeMenuListener) {
        mCustomizeMenuListener = customizeMenuListener;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view =
                LayoutInflater.from(parent.getContext())
                        .inflate(R.layout.custom_menu_item_layout, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        MenuItem currentMenuItem = getItem(position);
        if (CustomizeMenuUtils.sDividerIdList.contains(currentMenuItem.getItemId())) {
            showDivider(holder);
        } else {
            showMenuItem(holder, currentMenuItem);
        }
    }

    private void showDivider(ViewHolder holder) {
        holder.mDivider.setVisibility(View.VISIBLE);
        holder.mMenuItemContainer.setVisibility(View.GONE);
    }

    private void showMenuItem(ViewHolder holder, MenuItem currentMenuItem) {
        holder.mDivider.setVisibility(View.GONE);
        holder.mMenuItemContainer.setVisibility(View.VISIBLE);

        String title = currentMenuItem.getTitle().toString();
        if (CustomizeMenuUtils.sContexualIdList.contains(currentMenuItem.getItemId())) {
            title = title + "*";
            SpannableString spannableString = new SpannableString(title);
            ForegroundColorSpan foregroundSpan =
                    new ForegroundColorSpan(
                            holder.itemView.getContext().getColor(R.color.system_feedback_error));
            spannableString.setSpan(
                    foregroundSpan,
                    title.length() - 1,
                    title.length(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            holder.mMenuItemText.setText(spannableString);
        } else {
            holder.mMenuItemText.setText(title);
        }

        boolean isSelected =
                ChromeSharedPreferences.getInstance()
                        .readBoolean(String.valueOf(currentMenuItem.getItemId()), true);
        holder.mMenuItemSwitch.setChecked(isSelected);
        holder.mMenuItemIcon.setImageDrawable(currentMenuItem.getIcon());

        holder.itemView.setOnClickListener(
                v -> {
                    if (mCustomizeMenuListener != null) {
                        boolean isShown = holder.mMenuItemSwitch.isChecked();
                        holder.mMenuItemSwitch.setChecked(!isShown);
                        mCustomizeMenuListener.onMenuItemSelected(currentMenuItem, !isShown);
                    }
                });
    }

    static class ViewHolder extends RecyclerView.ViewHolder {

        final View mMenuItemContainer;
        final ImageView mMenuItemIcon;
        final TextView mMenuItemText;
        final MaterialSwitch mMenuItemSwitch;
        final View mDivider;

        ViewHolder(View itemView) {
            super(itemView);
            mMenuItemContainer = itemView.findViewById(R.id.menu_item_container);
            mMenuItemIcon = itemView.findViewById(R.id.menu_item_icon);
            mMenuItemText = itemView.findViewById(R.id.menu_item_text);
            mMenuItemSwitch = itemView.findViewById(R.id.menu_item_switch);
            mDivider = itemView.findViewById(R.id.divider);
        }
    }
}
