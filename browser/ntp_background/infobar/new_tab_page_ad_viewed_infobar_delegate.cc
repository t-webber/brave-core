/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "brave/browser/ntp_background/infobar/new_tab_page_ad_viewed_infobar_delegate.h"

#include <memory>

#include "brave/components/brave_ads/core/public/prefs/pref_names.h"
#include "brave/grit/brave_generated_resources.h"
#include "build/build_config.h"
#include "chrome/browser/infobars/confirm_infobar_creator.h"
#include "components/infobars/content/content_infobar_manager.h"
#include "components/infobars/core/infobar.h"
#include "components/prefs/pref_service.h"
#include "components/strings/grit/components_strings.h"
#include "components/vector_icons/vector_icons.h"
#include "content/public/browser/web_contents.h"
#include "ui/base/l10n/l10n_util.h"
#include "ui/base/models/image_model.h"
#include "url/gurl.h"
#include "brave/components/ntp_background_images/common/pref_names.h"

namespace ntp_background_images {

namespace {

constexpr char kLearnMoreUrl[] =
    "https://search.brave.com/help/conversion-reporting";

}  // namespace

// static
void NewTabPageAdViewedInfoBarDelegate::Create(
    content::WebContents* web_contents,
    PrefService* prefs) {
  CHECK(web_contents);
  CHECK(prefs);

  if (!prefs->GetBoolean(prefs::kShouldShowNewTabPageAdViewedInfoBar)) {
    return;
  }
  prefs->SetBoolean(prefs::kShouldShowNewTabPageAdViewedInfoBar, false);

  infobars::ContentInfoBarManager* infobar_manager =
      infobars::ContentInfoBarManager::FromWebContents(web_contents);
  if (!infobar_manager) {
    return;
  }
  infobar_manager->AddInfoBar(CreateConfirmInfoBar(
      std::make_unique<NewTabPageAdViewedInfoBarDelegate>()));
}

NewTabPageAdViewedInfoBarDelegate::NewTabPageAdViewedInfoBarDelegate() =
    default;

NewTabPageAdViewedInfoBarDelegate::~NewTabPageAdViewedInfoBarDelegate() =
    default;

infobars::InfoBarDelegate::InfoBarIdentifier
NewTabPageAdViewedInfoBarDelegate::GetIdentifier() const {
  return SEARCH_RESULT_AD_CLICKED_INFOBAR_DELEGATE;
}

ui::ImageModel NewTabPageAdViewedInfoBarDelegate::GetIcon() const {
#if BUILDFLAG(IS_ANDROID)
  return ui::ImageModel();
#else
  return ui::ImageModel::FromVectorIcon(vector_icons::kProductIcon,
                                        ui::kColorIcon, /*icon_size=*/20);
#endif  // BUILDFLAG(IS_ANDROID)
}

std::u16string NewTabPageAdViewedInfoBarDelegate::GetMessageText() const {
  return l10n_util::GetStringUTF16(
      IDS_BRAVE_ADS_SEARCH_RESULT_AD_CLICKED_INFOBAR_MESSAGE);
}

int NewTabPageAdViewedInfoBarDelegate::GetButtons() const {
  return BUTTON_NONE;
}

std::u16string NewTabPageAdViewedInfoBarDelegate::GetLinkText() const {
  return l10n_util::GetStringUTF16(
      IDS_BRAVE_ADS_SEARCH_RESULT_AD_LEARN_MORE_OPT_OUT_CHOICES_LABEL);
}

GURL NewTabPageAdViewedInfoBarDelegate::GetLinkURL() const {
  return GURL(kLearnMoreUrl);
}

bool NewTabPageAdViewedInfoBarDelegate::LinkClicked(
    WindowOpenDisposition disposition) {
  ConfirmInfoBarDelegate::LinkClicked(disposition);
  // Return true to immediately close the infobar.
  return true;
}

}  // namespace ntp_background_images
