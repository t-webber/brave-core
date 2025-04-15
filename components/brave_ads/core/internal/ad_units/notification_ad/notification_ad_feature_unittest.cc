/* Copyright (c) 2023 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "brave/components/brave_ads/core/public/ad_units/notification_ad/notification_ad_feature.h"

#include "base/time/time.h"
#include "testing/gtest/include/gtest/gtest.h"

// npm run test -- brave_unit_tests --filter=BraveAds*

namespace brave_ads {

TEST(BraveAdsNotificationAdFeatureTest, IsEnabled) {
  // Act & Assert
  EXPECT_TRUE(base::FeatureList::IsEnabled(kNotificationAdFeature));
}

TEST(BraveAdsNotificationAdFeatureTest, NotificationAdTimeout) {
  // Act & Assert
  EXPECT_EQ(base::Minutes(2), kNotificationAdTimeout.Get());
}

TEST(BraveAdsNotificationAdFeatureTest, DefaultNotificationAdsPerHour) {
  // Act & Assert
  EXPECT_EQ(10, kDefaultNotificationAdsPerHour.Get());
}

TEST(BraveAdsNotificationAdFeatureTest, MaximumNotificationAdsPerDay) {
  // Act & Assert
  EXPECT_EQ(100U, kMaximumNotificationAdsPerDay.Get());
}

TEST(BraveAdsNotificationAdFeatureTest, CanFallbackToCustomNotificationAds) {
  // Act & Assert
  EXPECT_FALSE(kCanFallbackToCustomNotificationAds.Get());
}

}  // namespace brave_ads
