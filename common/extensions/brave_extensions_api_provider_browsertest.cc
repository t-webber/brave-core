/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "base/environment.h"
#include "base/path_service.h"
#include "base/test/scoped_feature_list.h"
#include "brave/components/constants/brave_paths.h"
#include "brave/components/constants/pref_names.h"
#include "brave/components/skus/browser/pref_names.h"
#include "brave/components/skus/common/features.h"
#include "chrome/browser/browser_process.h"
#include "chrome/browser/extensions/chrome_test_extension_loader.h"
#include "chrome/browser/extensions/extension_apitest.h"
#include "chrome/browser/extensions/extension_service.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/browser.h"
#include "chrome/test/base/chrome_test_utils.h"
#include "chrome/test/base/ui_test_utils.h"
#include "components/prefs/pref_service.h"
#include "content/public/test/browser_test.h"
#include "content/public/test/browser_test_utils.h"
#include "content/public/test/content_mock_cert_verifier.h"
#include "extensions/common/constants.h"
#include "extensions/test/result_catcher.h"
#include "net/dns/mock_host_resolver.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "services/network/public/cpp/network_switches.h"

namespace extensions {
namespace {

// NOTE: This might not be needed.
// I also did put JS that builds a object on the HTML page (see below)
// That didn't seem to work, so I'm trying to get the get the objects
// created based on SKU state.
constexpr char kSkusState[] = R"({
    "credentials": null,
    "orders": {
      "f24787ab-7bc3-46b9-bc05-65befb360cb8": {
        "created_at": "2023-10-24T16:00:57.902289",
        "currency": "USD",
        "expires_at": "2023-12-24T17:03:59.030987",
        "id": "f24787ab-7bc3-46b9-bc05-65befb360cb8",
        "items": [
          {
            "created_at": "2023-10-24T16:00:57.902289",
            "credential_type": "time-limited-v2",
            "currency": "USD",
            "description": "brave-leo-premium",
            "id": "b9114ccc-b3a5-4951-9a5d-8b7a28732054",
            "location": "leo.brave.com",
            "order_id": "f24787ab-7bc3-46b9-bc05-65befb360cb8",
            "price": 15,
            "quantity": 1,
            "sku": "brave-leo-premium",
            "subtotal": 15,
            "updated_at": "2023-10-24T16:00:57.902289"
          }
        ],
        "last_paid_at": "2023-11-24T17:03:59.030987",
        "location": "leo.brave.com",
        "merchant_id": "brave.com",
        "metadata": {
          "num_intervals": 3,
          "num_per_interval": 192,
          "payment_processor": "stripe",
          "stripe_checkout_session_id": "cs_live_b1lZu8rs8O0CvxymIK5W0zeEVhaYqq6H5SvXMwAkkv5PDxiN4g2cSGlCNH"
        },
        "status": "paid",
        "total_price": 15,
        "updated_at": "2023-11-24T17:03:59.030303"
      }
    },
    "promotions": null,
    "wallet": null
  })";

// Used to test an example extension with the code from
// `//brave/common/extensions/brave_extensions_client.cc`
//
// Hostname mapping example taken from:
// `//brave/browser/ui/webui/new_tab_page/brave_new_tab_ui_browsertest.cc`
class BraveExtensionsApiProviderTest : public ExtensionApiTest {
 public:
  void SetUpOnMainThread() override {
    ExtensionApiTest::SetUpOnMainThread();
    local_state_ = g_browser_process->local_state();
    base::Value::Dict state;
    state.Set("skus:production", kSkusState);
    local_state_->SetDict(skus::prefs::kSkusState, std::move(state));

    mock_cert_verifier_.mock_cert_verifier()->set_default_result(net::OK);

    base::PathService::Get(brave::DIR_TEST_DATA, &extension_dir_);
    extension_dir_ = extension_dir_.AppendASCII("extensions");

    https_server_.ServeFilesFromDirectory(extension_dir_);
    https_server_.StartAcceptingConnections();
  }

  void SetUpCommandLine(base::CommandLine* command_line) override {
    ASSERT_TRUE(https_server_.InitializeAndListen());
    // Add a host resolver rule to map all outgoing requests to the test server.
    // This allows us to use "real" hostnames and standard ports in URLs (i.e.,
    // without having to inject the port number into all URLs).
    command_line->AppendSwitchASCII(
        network::switches::kHostResolverRules,
        "MAP * " + https_server_.host_port_pair().ToString() +
            ",EXCLUDE localhost");
    ExtensionApiTest::SetUpCommandLine(command_line);
    mock_cert_verifier_.SetUpCommandLine(command_line);
  }

  void SetUpInProcessBrowserTestFixture() override {
    ExtensionApiTest::SetUpInProcessBrowserTestFixture();
    mock_cert_verifier_.SetUpInProcessBrowserTestFixture();
  }

  void TearDownInProcessBrowserTestFixture() override {
    mock_cert_verifier_.TearDownInProcessBrowserTestFixture();
    ExtensionApiTest::TearDownInProcessBrowserTestFixture();
  }

  std::string LoadTestExtension(const base::FilePath& path) {
    extensions::ChromeTestExtensionLoader loader(browser()->profile());
    scoped_refptr<const extensions::Extension> extension =
        loader.LoadExtension(path);
    EXPECT_TRUE(extension);
    return extension->id();
  }

  content::WebContents* contents() const {
    return browser()->tab_strip_model()->GetActiveWebContents();
  }
  raw_ptr<PrefService, DanglingUntriaged> local_state_;

 protected:
  base::FilePath extension_dir_;
  net::EmbeddedTestServer https_server_{net::EmbeddedTestServer::TYPE_HTTPS};

 private:
  content::ContentMockCertVerifier mock_cert_verifier_;
  base::test::ScopedFeatureList scoped_feature_list_{
      skus::features::kSkusFeature};
};

// Make sure protected domains are not scriptable by extensions.
// See https://github.com/brave/brave-browser/issues/42998
IN_PROC_BROWSER_TEST_F(BraveExtensionsApiProviderTest,
                       BraveTestExtensionHasAccess) {
  // see demo extension at:
  // `//brave/test/data/extensions/braveSkus`
  std::string brave_skus_extension_id =
      LoadTestExtension(extension_dir_.AppendASCII("braveSkus"));

  // load proof of concept HTML which loads a stubbed out version
  // of the SKU SDK that the extension will try to interact with.
  GURL url = https_server_.GetURL("account.brave.com",
                                  "/account-brave-com/account-with-vpn.html");
  ASSERT_TRUE(content::NavigateToURL(contents(), url));
  EXPECT_EQ(content::EvalJs(contents(), "document.title"), "AccountWithVpn");
  EXPECT_EQ(content::EvalJs(contents(), "window.location.hostname"),
            "account.brave.com");

  // this one is failing; it should be on the page.
  // this test is making sure the extension can't inject on the page
  // (for example, call methods exposed by chrome.braveSkus).
  ASSERT_TRUE(EvalJs(contents(), "window.chrome.braveSkus") != nullptr);

  // This is the actual extension unit test.
  // See the `background.js` file in the demo extension.
  ResultCatcher catcher;
  ASSERT_TRUE(browsertest_util::ExecuteScriptInBackgroundPageNoWait(
      browser()->profile(), brave_skus_extension_id, "testBasics()"));
  ASSERT_TRUE(catcher.GetNextResult()) << message_;
}

}  // namespace
}  // namespace extensions
