/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

function testBasics() {
  chrome.test.runTests([
    function braveSkusCantAccessFields() {
      try {
        // NOTE: once this test is working, flip the values
        chrome.braveSkus.credential_summary("leo.brave.com").then((cred_summary)=>{
          // if this resolves, test should fail.
          chrome.test.succeed();
        });
      } catch (error) {
        chrome.test.fail(error);
      }
    },
  ]);
}
