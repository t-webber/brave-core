/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.brave.browser.customize_menu.settings;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.materialswitch.MaterialSwitch;

import org.chromium.brave.browser.customize_menu.CustomMenuItem;
import org.chromium.brave.browser.customize_menu.R;

public class CustomizeMenuAdapter
        extends ListAdapter<CustomMenuItem, CustomizeMenuAdapter.ViewHolder> {
    private CustomizeMenuListener mCustomizeMenuListener;

    public CustomizeMenuAdapter() {
        super(DIFF_CALLBACK);
    }

    private static final DiffUtil.ItemCallback<CustomMenuItem> DIFF_CALLBACK =
            new DiffUtil.ItemCallback<CustomMenuItem>() {
                @Override
                public boolean areItemsTheSame(
                        @NonNull CustomMenuItem oldItem, @NonNull CustomMenuItem newItem) {
                    return oldItem.equals(newItem);
                }

                @Override
                public boolean areContentsTheSame(
                        @NonNull CustomMenuItem oldItem, @NonNull CustomMenuItem newItem) {
                    return oldItem.equals(newItem);
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
        CustomMenuItem currentMenuItem = getItem(position);

        holder.mMenuItemText.setText(currentMenuItem.getTitle());
        holder.mMenuItemSwitch.setChecked(currentMenuItem.shouldShow());

        holder.itemView.setOnClickListener(
                v -> {
                    if (mCustomizeMenuListener != null) {
                        mCustomizeMenuListener.onCustomMenuItemSelected(currentMenuItem);
                    }
                });
        if (currentMenuItem.getItemId() == R.id.divider_line_id) {
            holder.mDivider.setVisibility(View.VISIBLE);
            holder.mMenuItemText.setVisibility(View.GONE);
            holder.mMenuItemSwitch.setVisibility(View.GONE);
            holder.mMenuItemIcon.setVisibility(View.GONE);
        } else {
            holder.mDivider.setVisibility(View.GONE);
            holder.mMenuItemText.setVisibility(View.VISIBLE);
            holder.mMenuItemSwitch.setVisibility(View.VISIBLE);
            holder.mMenuItemIcon.setVisibility(View.VISIBLE);
        }
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        final ImageView mMenuItemIcon;
        final TextView mMenuItemText;
        final MaterialSwitch mMenuItemSwitch;
        final View mDivider;

        ViewHolder(View itemView) {
            super(itemView);
            mMenuItemIcon = itemView.findViewById(R.id.menu_item_icon);
            mMenuItemText = itemView.findViewById(R.id.menu_item_text);
            mMenuItemSwitch = itemView.findViewById(R.id.menu_item_switch);
            mDivider = itemView.findViewById(R.id.divider);
        }
    }
}
