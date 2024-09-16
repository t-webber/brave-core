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

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import org.chromium.base.ContextUtils;
import org.chromium.base.Log;
import org.chromium.components.safe_browsing.SafeBrowsingApiHandler.LookupResult;

import java.util.ArrayList;


import com.google.api.services.safebrowsing.v5.Safebrowsing;
//     com/google/api/services/safebrowsing/v5/Safebrowsing.class

// import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
// import com.google.api.client.json.jackson2.JacksonFactory;
// import com.google.api.services.safebrowsing.v5.SafeBrowsing;
// import com.google.api.services.safebrowsing.v5.model.GoogleSecuritySafebrowsingV4FindThreatMatchesRequest;
// import com.google.api.services.safebrowsing.v5.model.GoogleSecuritySafebrowsingV4FindThreatMatchesResponse;


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
Log.e("TAG", "BraveSafeBrowsingApiHandler.getInstance 000");
        synchronized (sLock) {
            if (sInstance == null) {
Log.e("TAG", "BraveSafeBrowsingApiHandler.getInstance 001 create");
                sInstance = new BraveSafeBrowsingApiHandler();
            } else{
Log.e("TAG", "BraveSafeBrowsingApiHandler.getInstance 002 use existing");
            }
        }
        return sInstance;
    }

    public void setDelegate(String apiKey,
            BraveSafeBrowsingApiHandlerDelegate braveSafeBrowsingApiHandlerDelegate) {
Log.e("TAG", "BraveSafeBrowsingApiHandler.setDelegate 000");
Log.e("TAG", "apiKey                              ="+apiKey);
Log.e("TAG", "braveSafeBrowsingApiHandlerDelegate ="+braveSafeBrowsingApiHandlerDelegate);
        mApiKey = apiKey;
        mTriesCount = 0;
        mBraveSafeBrowsingApiHandlerDelegate = braveSafeBrowsingApiHandlerDelegate;
        assert mBraveSafeBrowsingApiHandlerDelegate
                != null : "BraveSafeBrowsingApiHandlerDelegate has to be initialized";
    }

    private void resetDelegate() {
        mBraveSafeBrowsingApiHandlerDelegate = null;
    }

    // @Override
    // public boolean init(Observer observer) {
    //     mObserver = observer;
    //     return true;
    // }
    @Override
    public void setObserver(SafeBrowsingApiHandler.Observer observer) {
        mObserver = observer;
    }

    @Override
    //public void startUriLookup(final long callbackId, String uri, int[] threatsOfInterest) {
    public void startUriLookup(        long callbackId, String uri, int[] threatTypes, int protocol) {
Log.e("TAG", "startUriLookup 000");
Log.e("TAG", "callbackId         ="+callbackId);
Log.e("TAG", "uri.length()       ="+uri.length());
Log.e("TAG", "uri                ="+uri);
Log.e("TAG", "threatTypes.length ="+threatTypes.length);
for (int threatType : threatTypes) {
Log.e("TAG", "threatTypes[i]     ="+threatType);
}
Log.e("TAG", "protocol           ="+protocol);

//Safebrowsing safebrowsing = null;
Safebrowsing safebrowsing = new Safebrowsing.Builder(
                 GoogleNetHttpTransport.newTrustedTransport(),
                 JacksonFactory.getDefaultInstance(),
                 null
         ).setApplicationName("Brave Browser")
          .setGoogleClientRequestInitializer(request -> request.put("key", "API_KEY")) //API_KEY
          .build();
Log.e("TAG", "safebrowsing       ="+safebrowsing);

Log.e("TAG", "mBraveSafeBrowsingApiHandlerDelegate ="+mBraveSafeBrowsingApiHandlerDelegate);

        if (mBraveSafeBrowsingApiHandlerDelegate == null
                || !mBraveSafeBrowsingApiHandlerDelegate.isSafeBrowsingEnabled()
                || !isHttpsOrHttp(uri)) {
Log.e("TAG", "startUriLookup 001 FAILURE_API_CALL_TIMEOUT");
            mObserver.onUrlCheckDone(
                    callbackId, // long callbackId,
                    LookupResult.FAILURE_API_CALL_TIMEOUT, // @LookupResult int lookupResult, 
                    0,//threatTypes[0], //int threatType
                    new int[0],
                    0, // responseStatus
                    DEFAULT_CHECK_DELTA//long checkDeltaMs
                    );
            return;
        }
        mTriesCount++;
Log.e("TAG", "startUriLookup 001 mTriesCount="+mTriesCount);
Log.e("TAG", "startUriLookup 001 mInitialized="+mInitialized);
        if (!mInitialized) {
            initSafeBrowsing();
        }
Log.e("TAG", "startUriLookup 002");
        SafetyNet.getClient(ContextUtils.getApplicationContext())
                .lookupUri(uri, mApiKey, /*threatsOfInterest*/threatTypes)
                .addOnSuccessListener(mBraveSafeBrowsingApiHandlerDelegate.getActivity(),
                        sbResponse -> {
Log.e("TAG", "startUriLookup onSuccess 000 sbResponse="+sbResponse);
Log.e("TAG", "startUriLookup onSuccess 001 sbResponse.getDetectedThreats().size()="+sbResponse.getDetectedThreats().size());
                            mTriesCount = 0;
                            //try {

                                //ArrayList<Integer> arrThreatTypes = new ArrayList();

                                int[] arrThreatTypes = new int[sbResponse.getDetectedThreats().size()];

                                //String metadata = SAFE_METADATA;
                                if (!sbResponse.getDetectedThreats().isEmpty()) {
                                    // JSONArray jsonArray = new JSONArray();
                                    for (int i = 0; i < sbResponse.getDetectedThreats().size();
                                             i++) {
                                    //     JSONObject jsonObj = new JSONObject();
                                    //     jsonObj.put("threat_type",
                                    //             String.valueOf(sbResponse.getDetectedThreats()
                                    //                                    .get(i)
                                    //                                    .getThreatType()));
                                    //     jsonArray.put(jsonObj);

                                        //arrThreatTypes.add(sbResponse.getDetectedThreats().get(i).getThreatType());
                                        arrThreatTypes[i] = sbResponse.getDetectedThreats().get(i).getThreatType();
Log.e("TAG", "startUriLookup onSuccess 002 arrThreatTypes["+i+"]="+arrThreatTypes[i]);
                                    }
                                    // JSONObject finalObj = new JSONObject();
                                    // finalObj.put("matches", jsonArray);
                                    // metadata = finalObj.toString();
                                }
                                if (mObserver != null) {
                                    mObserver.onUrlCheckDone(
                                        callbackId, 
                                        LookupResult.SUCCESS,
                                        arrThreatTypes.length>0?arrThreatTypes[0]:0,//int threatType
                                        arrThreatTypes,//int[] threatAttributes,
                                        0,//int responseStatus,
                                        DEFAULT_CHECK_DELTA //long checkDeltaMs
                                        
                                        );
                                }
                            // } catch (JSONException e) {
                            // }
                        })
                .addOnFailureListener(mBraveSafeBrowsingApiHandlerDelegate.getActivity(), e -> {
Log.e("TAG", "startUriLookup - onFailure 000 e="+e);
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
                            /*mObserver.onUrlCheckDone(callbackId, SafeBrowsingResult.TIMEOUT, "{}",
                                    DEFAULT_CHECK_DELTA);*/
                            mObserver.onUrlCheckDone(
                                callbackId, // long callbackId,
                                LookupResult.FAILURE_API_CALL_TIMEOUT, // @LookupResult int lookupResult, 
                                threatTypes[0], //int threatType
                                new int[0],
                                0, // responseStatus
                                DEFAULT_CHECK_DELTA//long checkDeltaMs
                                );                                    
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

    // @Override
    // public boolean startAllowlistLookup(final String uri, int threatType) {
    //     return false;
    // }

    public void initSafeBrowsing() {
Log.e("TAG", "BraveSafeBrowsingApiHandler.initSafeBrowsing 000");
        SafetyNet.getClient(ContextUtils.getApplicationContext()).initSafeBrowsing();
        mInitialized = true;
    }

    public void shutdownSafeBrowsing() {
Log.e("TAG", "BraveSafeBrowsingApiHandler.shutdownSafeBrowsing 000");
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

    // @Override
    // public void isVerifyAppsEnabled(long callbackId) {
    //     mObserver.onVerifyAppsEnabledDone(callbackId, VerifyAppsResult.SUCCESS_ENABLED);
    // }

    // @Override
    // public void enableVerifyApps(long callbackId) {
    //     mObserver.onVerifyAppsEnabledDone(callbackId, VerifyAppsResult.SUCCESS_ENABLED);
    // }
}
