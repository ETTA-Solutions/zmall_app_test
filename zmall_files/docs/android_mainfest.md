# ZMall ChatGPT Integration - Backend Developer Guide

> This document explains the entire Android configuration and user flow for ChatGPT integration in the ZMall app.

---

## 📋 Table of Contents

1. [Android Manifest Configuration](#android-manifest-configuration)
2. [User Flow Diagram](#user-flow-diagram)
3. [API Endpoints Required](#api-endpoints-required)
4. [Database Schema](#database-schema)
5. [Configuration Values](#configuration-values)

---

## Android Manifest Configuration

### Complete AndroidManifest.xml

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- package="com.enigma.zmall"> -->

    <!-- ===== PERMISSIONS ===== -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />

    <!-- ChatGPT/AI Chatbot Permissions -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <!-- ===== APPLICATION ===== -->
    <application
        android:label="ZMall"
        android:usesCleartextTraffic="true"
        android:icon="@mipmap/ic_launcher"
        android:networkSecurityConfig="@xml/network_security_config">

        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:requestLegacyExternalStorage="true"
            android:windowSoftInputMode="adjustResize"
            android:enableOnBackInvokedCallback="true">

            <!-- Flutter Theme -->
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <!-- Splash Screen -->
            <meta-data
                android:name="io.flutter.embedding.android.SplashScreenDrawable"
                android:resource="@drawable/launch_background" />

            <!-- Launch Intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

            <!-- Notification Click Intent -->
            <intent-filter>
                <action android:name="FLUTTER_NOTIFICATION_CLICK" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>

            <!-- Deep Linking Support -->
            <meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="http" android:host="zmall.page.link" />
                <data android:scheme="https" />
            </intent-filter>
        </activity>

        <!-- ===== METADATA CONFIGURATION ===== -->

        <!-- Flutter Embedding Version -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <!-- Google Maps API Key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="AIzaSyBzMHLnXLbtLMi9rVFOR0eo5pbouBtxyjg" />

        <!-- Firebase Messaging Configuration -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notifications" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/colorPrimary" />

        <!-- Facebook Analytics Configuration -->
        <meta-data
            android:name="com.facebook.sdk.ApplicationId"
            android:value="fb1050203588837738" />
        <meta-data
            android:name="com.facebook.sdk.ClientToken"
            android:value="3167abc63899705752c31bea73fae744" />

        <!-- ===== CHATGPT/AI CHATBOT CONFIGURATION ===== -->
        <meta-data
            android:name="chatgpt_enabled"
            android:value="true" />
        <meta-data
            android:name="chatgpt_service_name"
            android:value="ZMall AI Support" />

    </application>
</manifest>
```

### Network Security Config

**Location:** `android/app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Allow cleartext for localhost and development -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
    </domain-config>

    <!-- OpenAI ChatGPT API (HTTPS only) -->
    <domain-config>
        <domain includeSubdomains="true">api.openai.com</domain>
    </domain-config>

    <!-- Your Backend Server -->
    <domain-config>
        <domain includeSubdomains="true">your-backend-domain.com</domain>
    </domain-config>
</network-security-config>
```

---

## User Flow Diagram

### Complete User Journey: Login → Item → Checkout → ChatGPT Support

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SPLASH SCREEN                                            │
│    └─ Shows ZMall logo                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. LOGIN SCREEN                                             │
│    ├─ Phone Number + Password                              │
│    ├─ OTP Verification                                     │
│    ├─ Biometric Authentication (optional)                  │
│    └─ Backend: POST /api/user/verify_otp                   │
│       Backend: POST /api/user/login                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. HOME SCREEN (TabScreen)                                  │
│    ├─ Check: is_chatbot_active (from user data)            │
│    ├─ If TRUE: Show 4 tabs                                 │
│    │  ├─ Home                                               │
│    │  ├─ Orders                                             │
│    │  ├─ ChatGPT Support ⭐ (NEW)                           │
│    │  └─ Profile                                            │
│    │                                                        │
│    └─ If FALSE: Show 3 tabs                                │
│       ├─ Home                                               │
│       ├─ Orders                                             │
│       └─ Profile                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. HOME PAGE                                                │
│    ├─ Browse Products/Items                                │
│    ├─ Search Items                                         │
│    ├─ View Categories                                      │
│    └─ Backend: GET /api/products                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. ITEM DETAIL SCREEN                                       │
│    ├─ Product Details                                      │
│    ├─ Price, Description                                   │
│    ├─ Add to Cart Button                                   │
│    └─ Backend: GET /api/products/{product_id}              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. CART SCREEN                                              │
│    ├─ Review Items                                         │
│    ├─ Adjust Quantities                                    │
│    ├─ View Total Price                                     │
│    └─ "Proceed to Checkout" Button                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. CHECKOUT SCREEN ⭐                                        │
│    ├─ Delivery Address                                     │
│    ├─ Payment Method                                       │
│    ├─ Order Summary                                        │
│    ├─ Order Confirmation                                   │
│    └─ Backend: POST /api/orders/create                     │
│       Backend: POST /api/payments/process                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. CHATGPT SUPPORT (If is_chatbot_active = true)            │
│    ├─ Questions about Order?                               │
│    ├─ Track Delivery?                                      │
│    ├─ Need Help with Payment?                              │
│    ├─ AI Chatbot responds in real-time                     │
│    └─ Backend API Calls:                                   │
│       ├─ POST /api/chatgpt/send-message                    │
│       ├─ GET /api/chatgpt/conversations/{user_id}          │
│       └─ GET /api/chatgpt/messages/{conversation_id}       │
└─────────────────────────────────────────────────────────────┘
```
