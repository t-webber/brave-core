// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#include "brave/browser/ui/webui/brave_new_tab_page_refresh/brave_new_tab_page_ui.h"

#include <utility>

#include "brave/browser/brave_ads/ads_service_factory.h"
#include "brave/browser/brave_browser_process.h"
#include "brave/browser/new_tab/new_tab_shows_options.h"
#include "brave/browser/ntp_background/brave_ntp_custom_background_service_factory.h"
#include "brave/browser/ntp_background/custom_background_file_manager.h"
#include "brave/browser/ntp_background/ntp_p3a_helper_impl.h"
#include "brave/browser/ntp_background/view_counter_service_factory.h"
#include "brave/browser/resources/brave_new_tab_page_refresh/grit/brave_new_tab_page_refresh_generated_map.h"
#include "brave/browser/ui/webui/brave_new_tab_page_refresh/background_facade.h"
#include "brave/browser/ui/webui/brave_new_tab_page_refresh/custom_image_chooser.h"
#include "brave/browser/ui/webui/brave_new_tab_page_refresh/new_tab_page_handler.h"
#include "brave/browser/ui/webui/brave_webui_source.h"
#include "brave/components/l10n/common/localization_util.h"
#include "brave/components/ntp_background_images/browser/ntp_custom_images_source.h"
#include "brave/components/ntp_background_images/browser/ntp_sponsored_rich_media_ad_event_handler.h"
#include "chrome/browser/browser_process.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/themes/theme_syncable_service.h"
#include "chrome/browser/ui/webui/favicon_source.h"
#include "components/favicon_base/favicon_url_parser.h"
#include "components/grit/brave_components_resources.h"
#include "components/grit/brave_components_strings.h"
#include "components/prefs/pref_service.h"
#include "components/strings/grit/components_strings.h"
#include "content/public/browser/web_ui.h"
#include "content/public/browser/web_ui_data_source.h"
#include "ui/webui/webui_util.h"

namespace {

using brave_new_tab_page_refresh::BackgroundFacade;
using brave_new_tab_page_refresh::CustomImageChooser;
using brave_new_tab_page_refresh::NewTabPageHandler;

static constexpr webui::LocalizedString kStrings[] = {
    {"addTopSiteLabel", IDS_NEW_TAB_ADD_TOP_SITE_LABEL},
    {"addTopSiteTitle", IDS_NEW_TAB_ADD_TOP_SITE_TITLE},
    {"backgroundSettingsTitle", IDS_NEW_TAB_BACKGROUND_SETTINGS_TITLE},
    {"braveBackgroundLabel", IDS_NEW_TAB_BRAVE_BACKGROUND_LABEL},
    {"cancelButtonLabel", IDS_NEW_TAB_CANCEL_BUTTON_LABEL},
    {"clockFormatLabel", IDS_NEW_TAB_CLOCK_FORMAT_LABEL},
    {"clockFormatOption12HourText", IDS_NEW_TAB_CLOCK_FORMAT_OPTION12HOUR_TEXT},
    {"clockFormatOption24HourText", IDS_NEW_TAB_CLOCK_FORMAT_OPTION24HOUR_TEXT},
    {"clockFormatOptionAutomaticText",
     IDS_NEW_TAB_CLOCK_FORMAT_OPTION_AUTOMATIC_TEXT},
    {"clockSettingsTitle", IDS_NEW_TAB_CLOCK_SETTINGS_TITLE},
    {"customBackgroundLabel", IDS_NEW_TAB_CUSTOM_BACKGROUND_LABEL},
    {"customBackgroundTitle", IDS_NEW_TAB_CUSTOM_BACKGROUND_LABEL},
    {"customizeSearchEnginesLink", IDS_NEW_TAB_CUSTOMIZE_SEARCH_ENGINES_LINK},
    {"editTopSiteLabel", IDS_NEW_TAB_EDIT_TOP_SITE_LABEL},
    {"editTopSiteTitle", IDS_NEW_TAB_EDIT_TOP_SITE_TITLE},
    {"enabledSearchEnginesLabel", IDS_NEW_TAB_ENABLED_SEARCH_ENGINES_LABEL},
    {"gradientBackgroundLabel", IDS_NEW_TAB_GRADIENT_BACKGROUND_LABEL},
    {"gradientBackgroundTitle", IDS_NEW_TAB_GRADIENT_BACKGROUND_LABEL},
    {"hideTopSitesLabel", IDS_NEW_TAB_HIDE_TOP_SITES_LABEL},
    {"photoCreditsText", IDS_NEW_TAB_PHOTO_CREDITS_TEXT},
    {"randomizeBackgroundLabel", IDS_NEW_TAB_RANDOMIZE_BACKGROUND_LABEL},
    {"removeTopSiteLabel", IDS_NEW_TAB_REMOVE_TOP_SITE_LABEL},
    {"rewardsConnectButtonLabel", IDS_NEW_TAB_REWARDS_CONNECT_BUTTON_LABEL},
    {"rewardsFeatureText1", IDS_REWARDS_ONBOARDING_TEXT_ITEM_1},
    {"rewardsFeatureText2", IDS_REWARDS_ONBOARDING_TEXT_ITEM_2},
    {"rewardsOnboardingButtonLabel", IDS_REWARDS_ONBOARDING_BUTTON_LABEL},
    {"rewardsOnboardingLink", IDS_NEW_TAB_REWARDS_ONBOARDING_LINK},
    {"rewardsWidgetTitle", IDS_NEW_TAB_REWARDS_WIDGET_TITLE},
    {"saveChangesButtonLabel", IDS_NEW_TAB_SAVE_CHANGES_BUTTON_LABEL},
    {"searchAskLeoDescription", IDS_OMNIBOX_ASK_LEO_DESCRIPTION},
    {"searchBoxPlaceholderText", IDS_NEW_TAB_SEARCH_BOX_PLACEHOLDER_TEXT},
    {"searchBoxPlaceholderTextBrave",
     IDS_NEW_TAB_SEARCH_BOX_PLACEHOLDER_TEXT_BRAVE},
    {"searchCustomizeEngineListText",
     IDS_NEW_TAB_SEARCH_CUSTOMIZE_ENGINE_LIST_TEXT},
    {"searchSettingsTitle", IDS_NEW_TAB_SEARCH_SETTINGS_TITLE},
    {"searchSuggestionsDismissButtonLabel",
     IDS_NEW_TAB_SEARCH_SUGGESTIONS_DISMISS_BUTTON_LABEL},
    {"searchSuggestionsEnableButtonLabel",
     IDS_NEW_TAB_SEARCH_SUGGESTIONS_ENABLE_BUTTON_LABEL},
    {"searchSuggestionsPromptText", IDS_NEW_TAB_SEARCH_SUGGESTIONS_PROMPT_TEXT},
    {"searchSuggestionsPromptTitle",
     IDS_NEW_TAB_SEARCH_SUGGESTIONS_PROMPT_TITLE},
    {"settingsTitle", IDS_NEW_TAB_SETTINGS_TITLE},
    {"showBackgroundsLabel", IDS_NEW_TAB_SHOW_BACKGROUNDS_LABEL},
    {"showClockLabel", IDS_NEW_TAB_SHOW_CLOCK_LABEL},
    {"showRewardsWidgetLabel", IDS_NEW_TAB_SHOW_REWARDS_WIDGET_LABEL},
    {"showSearchBoxLabel", IDS_NEW_TAB_SHOW_SEARCH_BOX_LABEL},
    {"showSponsoredImagesLabel", IDS_NEW_TAB_SHOW_SPONSORED_IMAGES_LABEL},
    {"showStatsLabel", IDS_NEW_TAB_SHOW_STATS_LABEL},
    {"showTalkWidgetLabel", IDS_NEW_TAB_SHOW_TALK_WIDGET_LABEL},
    {"showTopSitesLabel", IDS_NEW_TAB_SHOW_TOP_SITES_LABEL},
    {"showVpnWidgetLabel", IDS_NEW_TAB_SHOW_VPN_WIDGET_LABEL},
    {"solidBackgroundLabel", IDS_NEW_TAB_SOLID_BACKGROUND_LABEL},
    {"solidBackgroundTitle", IDS_NEW_TAB_SOLID_BACKGROUND_LABEL},
    {"statsAdsBlockedText", IDS_NEW_TAB_STATS_ADS_BLOCKED_TEXT},
    {"statsBandwidthSavedText", IDS_NEW_TAB_STATS_BANDWIDTH_SAVED_TEXT},
    {"statsSettingsTitle", IDS_NEW_TAB_STATS_SETTINGS_TITLE},
    {"statsTimeSavedText", IDS_NEW_TAB_STATS_TIME_SAVED_TEXT},
    {"statsTitle", IDS_NEW_TAB_STATS_TITLE},
    {"talkDescriptionText", IDS_NEW_TAB_TALK_DESCRIPTION_TEXT},
    {"talkDescriptionTitle", IDS_NEW_TAB_TALK_DESCRIPTION_TITLE},
    {"talkStartCallLabel", IDS_NEW_TAB_TALK_START_CALL_LABEL},
    {"talkWidgetTitle", IDS_NEW_TAB_TALK_WIDGET_TITLE},
    {"topSiteRemovedText", IDS_NEW_TAB_TOP_SITE_REMOVED_TEXT},
    {"topSiteRemovedTitle", IDS_NEW_TAB_TOP_SITE_REMOVED_TITLE},
    {"topSitesCustomOptionText", IDS_NEW_TAB_TOP_SITES_CUSTOM_OPTION_TEXT},
    {"topSitesCustomOptionTitle", IDS_NEW_TAB_TOP_SITES_CUSTOM_OPTION_TITLE},
    {"topSitesMostVisitedOptionText",
     IDS_NEW_TAB_TOP_SITES_MOST_VISITED_OPTION_TEXT},
    {"topSitesMostVisitedOptionTitle",
     IDS_NEW_TAB_TOP_SITES_MOST_VISITED_OPTION_TITLE},
    {"topSitesSettingsTitle", IDS_NEW_TAB_TOP_SITES_SETTINGS_TITLE},
    {"topSitesShowCustomLabel", IDS_NEW_TAB_TOP_SITES_SHOW_CUSTOM_LABEL},
    {"topSitesShowMostVisitedLabel",
     IDS_NEW_TAB_TOP_SITES_SHOW_MOST_VISITED_LABEL},
    {"topSitesTitleLabel", IDS_NEW_TAB_TOP_SITES_TITLE_LABEL},
    {"topSitesURLLabel", IDS_NEW_TAB_TOP_SITES_URL_LABEL},
    {"undoButtonLabel", IDS_NEW_TAB_UNDO_BUTTON_LABEL},
    {"uploadBackgroundLabel", IDS_NEW_TAB_UPLOAD_BACKGROUND_LABEL},
    {"vpnChangeRegionLabel", IDS_NEW_TAB_VPN_CHANGE_REGION_LABEL},
    {"vpnFeatureText1", IDS_NEW_TAB_VPN_FEATURE_TEXT1},
    {"vpnFeatureText2", IDS_NEW_TAB_VPN_FEATURE_TEXT2},
    {"vpnFeatureText3", IDS_NEW_TAB_VPN_FEATURE_TEXT3},
    {"vpnRestorePurchaseLabel", IDS_NEW_TAB_VPN_RESTORE_PURCHASE_LABEL},
    {"vpnStartTrialLabel", IDS_NEW_TAB_VPN_START_TRIAL_LABEL},
    {"vpnOptimalText", IDS_NEW_TAB_VPN_OPTIMAL_TEXT},
    {"vpnPoweredByText", IDS_NEW_TAB_VPN_POWERED_BY_TEXT},
    {"vpnStatusConnected", IDS_NEW_TAB_VPN_STATUS_CONNECTED},
    {"vpnStatusConnecting", IDS_NEW_TAB_VPN_STATUS_CONNECTING},
    {"vpnStatusDisconnected", IDS_NEW_TAB_VPN_STATUS_DISCONNECTED},
    {"vpnStatusDisconnecting", IDS_NEW_TAB_VPN_STATUS_DISCONNECTING},
    {"vpnWidgetTitle", IDS_NEW_TAB_VPN_WIDGET_TITLE},
    {"widgetLayoutLabel", IDS_NEW_TAB_WIDGET_LAYOUT_LABEL},
    {"widgetSettingsTitle", IDS_NEW_TAB_WIDGET_SETTINGS_TITLE}};

// Adds support for displaying images stored in the custom background image
// folder.
void AddCustomImageDataSource(Profile* profile) {
  auto* custom_background_service =
      BraveNTPCustomBackgroundServiceFactory::GetForContext(profile);
  if (!custom_background_service) {
    return;
  }
  auto source = std::make_unique<ntp_background_images::NTPCustomImagesSource>(
      custom_background_service);
  content::URLDataSource::Add(profile, std::move(source));
}

}  // namespace

BraveNewTabPageUI::BraveNewTabPageUI(content::WebUI* web_ui)
    : ui::MojoWebUIController(web_ui) {
  auto* profile = Profile::FromWebUI(web_ui);

  auto* source = content::WebUIDataSource::CreateAndAdd(
      profile, chrome::kChromeUINewTabHost);

  if (brave::ShouldNewTabShowBlankpage(profile)) {
    source->SetDefaultResource(IDR_BRAVE_BLANK_NEW_TAB_HTML);
  } else {
    webui::SetupWebUIDataSource(source, kBraveNewTabPageRefreshGenerated,
                                IDR_BRAVE_NEW_TAB_PAGE_HTML);
  }

  source->OverrideContentSecurityPolicy(
      network::mojom::CSPDirectiveName::ImgSrc,
      "img-src chrome://resources chrome://theme chrome://background-wallpaper "
      "chrome://custom-wallpaper chrome://branded-wallpaper chrome://favicon2 "
      "blob: data: 'self';");

  AddBackgroundColorToSource(source, web_ui->GetWebContents());
  AddCustomImageDataSource(profile);

  content::URLDataSource::Add(
      profile, std::make_unique<FaviconSource>(
                   profile, chrome::FaviconUrlFormat::kFavicon2));

  web_ui->OverrideTitle(
      brave_l10n::GetLocalizedResourceUTF16String(IDS_NEW_TAB_TITLE));

  source->AddLocalizedStrings(kStrings);

  source->AddBoolean(
      "customBackgroundFeatureEnabled",
      !profile->GetPrefs()->IsManagedPreference(GetThemePrefNameInMigration(
          ThemePrefInMigration::kNtpCustomBackgroundDict)));
}

BraveNewTabPageUI::~BraveNewTabPageUI() = default;

void BraveNewTabPageUI::BindInterface(
    mojo::PendingReceiver<brave_new_tab_page_refresh::mojom::NewTabPageHandler>
        receiver) {
  auto* web_contents = web_ui()->GetWebContents();
  auto* profile = Profile::FromWebUI(web_ui());
  auto* prefs = profile->GetPrefs();

  auto image_chooser = std::make_unique<CustomImageChooser>(*web_contents);

  auto background_facade = std::make_unique<BackgroundFacade>(
      std::make_unique<CustomBackgroundFileManager>(profile), *prefs,
      ntp_background_images::ViewCounterServiceFactory::GetForProfile(profile));

  page_handler_ = std::make_unique<NewTabPageHandler>(
      std::move(receiver), std::move(image_chooser),
      std::move(background_facade), *prefs);
}

void BraveNewTabPageUI::BindInterface(
    mojo::PendingReceiver<
        ntp_background_images::mojom::SponsoredRichMediaAdEventHandler>
        receiver) {
  auto* profile = Profile::FromWebUI(web_ui());
  std::unique_ptr<ntp_background_images::NTPP3AHelperImpl> ntp_p3a_helper;
  if (g_brave_browser_process->p3a_service() != nullptr) {
    ntp_p3a_helper = std::make_unique<ntp_background_images::NTPP3AHelperImpl>(
        g_browser_process->local_state(),
        g_brave_browser_process->p3a_service(),
        g_brave_browser_process->ntp_background_images_service(),
        profile->GetPrefs());
  }
  rich_media_ad_event_handler_ = std::make_unique<
      ntp_background_images::NTPSponsoredRichMediaAdEventHandler>(
      brave_ads::AdsServiceFactory::GetForProfile(profile),
      std::move(ntp_p3a_helper));
}

WEB_UI_CONTROLLER_TYPE_IMPL(BraveNewTabPageUI)
