/* Copyright (c) 2022 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

package org.chromium.components.safe_browsing;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.webkit.URLUtil;

import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.safetynet.SafetyNet;
import com.google.android.gms.safetynet.SafetyNetStatusCodes;
import com.google.api.services.safebrowsing.v5.Safebrowsing;
import com.google.api.client.extensions.android.http.AndroidHttp;  // deprectted (https://cloud.google.com/java/docs/reference/google-http-client/latest/com.google.api.client.extensions.android.http)
import com.google.api.client.json.jackson2.JacksonFactory;

import java.util.ArrayList;
import java.security.GeneralSecurityException;
import java.io.IOException;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import org.chromium.base.ContextUtils;
import org.chromium.base.Log;
import org.chromium.components.safe_browsing.SafeBrowsingApiHandler.LookupResult;

/**
 * Brave implementation of SafetyNetApiHandler for Safe Browsing
 */
public class BraveSafeBrowsingApiHandler implements /*SafetyNetApiHandler*/SafeBrowsingApiHandler {
    public static final long SAFE_BROWSING_INIT_INTERVAL_MS = 30000;
    private static final long DEFAULT_CHECK_DELTA = 10;
    private static final String SAFE_METADATA = "{}";
    private static final String TAG = "BraveSafeBrowsingApiHandler";

    /**
     *This is a delegate that is implemented in the object where the handler is created
     */
    public interface BraveSafeBrowsingApiHandlerDelegate {
        default void turnSafeBrowsingOff() {}
        default boolean isSafeBrowsingEnabled() {
            return true;
        }
        Activity getActivity();
    }

    private SafeBrowsingApiHandler.Observer mObserver;
    private String mApiKey;
    private boolean mInitialized;
    private int mTriesCount;
    private BraveSafeBrowsingApiHandlerDelegate mBraveSafeBrowsingApiHandlerDelegate;
    private static final Object sLock = new Object();
    private static BraveSafeBrowsingApiHandler sInstance;

    public static BraveSafeBrowsingApiHandler getInstance() {
        synchronized (sLock) {
            if (sInstance == null) {
                sInstance = new BraveSafeBrowsingApiHandler();
            }
        }
        return sInstance;
    }

    public void setDelegate(String apiKey,
            BraveSafeBrowsingApiHandlerDelegate braveSafeBrowsingApiHandlerDelegate) {
        mApiKey = apiKey;
        mTriesCount = 0;
        mBraveSafeBrowsingApiHandlerDelegate = braveSafeBrowsingApiHandlerDelegate;
        assert mBraveSafeBrowsingApiHandlerDelegate
                != null : "BraveSafeBrowsingApiHandlerDelegate has to be initialized";
    }

    private void resetDelegate() {
        mBraveSafeBrowsingApiHandlerDelegate = null;
    }

    @Override
    public void setObserver(SafeBrowsingApiHandler.Observer observer) {
        mObserver = observer;
    }

    @Override
    public void startUriLookup(        long callbackId, String uri, int[] threatTypes, int protocol) {
        Safebrowsing safebrowsing = new Safebrowsing.Builder(
                        AndroidHttp.newCompatibleTransport(),
                 JacksonFactory.getDefaultInstance(),
                 null
         ).setApplicationName("Brave Browser")
          .setGoogleClientRequestInitializer(request -> request.put("key", "API_KEY")) //API_KEY
          .build();

        if (mBraveSafeBrowsingApiHandlerDelegate == null
                || !mBraveSafeBrowsingApiHandlerDelegate.isSafeBrowsingEnabled()
                || !isHttpsOrHttp(uri)) {
            mObserver.onUrlCheckDone(
                    callbackId,
                    LookupResult.FAILURE_API_CALL_TIMEOUT,
                    0,
                    new int[0],
                    0,
                    DEFAULT_CHECK_DELTA);
            return;
        }
        mTriesCount++;

        if (!mInitialized) {
            initSafeBrowsing();
        }

        SafetyNet.getClient(ContextUtils.getApplicationContext())
                .lookupUri(uri, mApiKey, /*threatsOfInterest*/threatTypes)
                .addOnSuccessListener(mBraveSafeBrowsingApiHandlerDelegate.getActivity(),
                        sbResponse -> {
                            mTriesCount = 0;

                                int[] arrThreatTypes = new int[sbResponse.getDetectedThreats().size()];

                                if (!sbResponse.getDetectedThreats().isEmpty()) {
                                    for (int i = 0; i < sbResponse.getDetectedThreats().size();
                                             i++) {
                                        arrThreatTypes[i] = sbResponse.getDetectedThreats().get(i).getThreatType();
                                    }
                                }
                                if (mObserver != null) {
                                    mObserver.onUrlCheckDone(
                                        callbackId, 
                                        LookupResult.SUCCESS,
                                        arrThreatTypes.length>0?arrThreatTypes[0]:0,
                                        arrThreatTypes,
                                        0,
                                        DEFAULT_CHECK_DELTA);
                                }
                        })
                .addOnFailureListener(mBraveSafeBrowsingApiHandlerDelegate.getActivity(), e -> {
                    // An error occurred while communicating with the service.
                    if (e instanceof ApiException) {
                        // An error with the Google Play Services API contains some
                        // additional details.
                        ApiException apiException = (ApiException) e;
                        if (isDebuggable()) {
                            Log.d(TAG,
                                    "Error: "
                                            + CommonStatusCodes.getStatusCodeString(
                                                    apiException.getStatusCode())
                                            + ", code: " + apiException.getStatusCode());
                        }
                        if (apiException.getStatusCode() == CommonStatusCodes.API_NOT_CONNECTED) {
                            // That means that device doesn't have Google Play Services API.
                            // Delegate is used to turn off safe browsing option as every request is
                            // delayed when it's turned on and not working
                            mBraveSafeBrowsingApiHandlerDelegate.turnSafeBrowsingOff();
                        }

                        // Note: If the status code, apiException.getStatusCode(),
                        // is SafetyNetStatusCodes.SAFE_BROWSING_API_NOT_INITIALIZED,
                        // you need to call initSafeBrowsing(). It means either you
                        // haven't called initSafeBrowsing() before or that it needs
                        // to be called again due to an internal error.
                        if (mTriesCount <= 1
                                && apiException.getStatusCode()
                                        == SafetyNetStatusCodes.SAFE_BROWSING_API_NOT_INITIALIZED) {
                            initSafeBrowsing();
                            //startUriLookup(callbackId, uri, threatsOfInterest);
                            startUriLookup(callbackId, uri, threatTypes, protocol);
                        } else {
                            mObserver.onUrlCheckDone(
                                callbackId,
                                LookupResult.FAILURE_API_CALL_TIMEOUT,
                                threatTypes[0],
                                new int[0],
                                0,
                                DEFAULT_CHECK_DELTA);                                    
                        }
                    } else {
                        // A different, unknown type of error occurred.
                        if (isDebuggable()) {
                            Log.d(TAG, "Error: " + e.getMessage());
                        }
                        mObserver.onUrlCheckDone(
                                callbackId, LookupResult.FAILURE_API_CALL_TIMEOUT, threatTypes[0], new int[0], 0, DEFAULT_CHECK_DELTA);
                    }
                    mTriesCount = 0;
                });

        
    }


    public void initSafeBrowsing() {
        SafetyNet.getClient(ContextUtils.getApplicationContext()).initSafeBrowsing();
        mInitialized = true;
    }

    public void shutdownSafeBrowsing() {
        if (!mInitialized) {
            return;
        }
        SafetyNet.getClient(ContextUtils.getApplicationContext()).shutdownSafeBrowsing();
        resetDelegate();
        mInitialized = false;
    }

    private boolean isDebuggable() {
        if (mBraveSafeBrowsingApiHandlerDelegate == null) {
            return false;
        }

        return 0
                != (mBraveSafeBrowsingApiHandlerDelegate.getActivity().getApplicationInfo().flags
                        & ApplicationInfo.FLAG_DEBUGGABLE);
    }

    private boolean isHttpsOrHttp(String uri) {
        return URLUtil.isHttpsUrl(uri) || URLUtil.isHttpUrl(uri);
    }
}
