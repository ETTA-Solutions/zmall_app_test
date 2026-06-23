# ZMall System Architecture Diagram

## Technical Diagrams

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TIER 1: CLIENTS & EXTERNAL                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────────┐         ┌────────────────────────────────┐  │
│  │  External Connections    │         │  Payment & External Services   │  │
│  │  ┌────────────────────┐  │         │  ┌──────────────────────────┐  │   │
│  │  │ ☁️  INTERNET       │  │         │  │ 🏦 Payment Gateways      │  │   │
│  │  │ 📱 Mobile Devices  │──┼────────▶│  │  • Telebirr (InApp)      │  │   │
│  │  │ 💳 POS Machines    │  │         │  │  • Chapa                 │  │   │
│  │  └────────────────────┘  │         │  │  • EthSwitch             │  │   │
│  └──────────────────────────┘         │  │  • Addis Pay             │  │   │
│                                       │  │  • Amole                 │  │   │
│                   │                   │  │  • Yagout Pay            │  │   │
│                   │                   │  │  • CBE USSD              │  │   │
│                   ▼                   │  │  • Dashen Bank           │  │   │
│  ┌──────────────────────────────────┐ │  │  • Etta Card             │  │   │
│  │  Google Services & Social        │ │  │  • SantiM Pay            │  │   │
│  │  • Google Maps API               │ │  │  • CyberSource           │  │   │
│  │  • Google OAuth                  │ │  └──────────────────────────┘  │   │
│  │  • Facebook Analytics            │ │                                │   │
│  │  • Facebook App Events           │ │                                │   │
│  └──────────────────────────────────┘ │                                │   │
│                                       │                                │   │
│                   │                   │                                │   │
│                   │                   └────────────────────────────────┘   │
└───────────────────┼────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TIER 2: BACKEND SERVERS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ 🖥️  ZMall Server (Main Backend)                                  │     │
│  │                                                                    │     │
│  │  • Production: http://196.188.187.43:8000                         │     │
│  │  • Test: http://196.189.44.49:7000                                │     │
│  │                                                                  │     │
│  │  ┌──────────────────────────────────────────────────────┐        │     │
│  │  │ REST API Endpoints                                   │        │     │
│  │  │  • /api/user/*        (User operations)              │        │     │
│  │  │  • /api/admin/*       (Admin operations)             │        │     │
│  │  │  • /api/store/*       (Store operations)             │        │     │
│  │  │  • Authentication, Orders, Cart, Products, etc.      │        │     │
│  │  └──────────────────────────────────────────────────────┘        │     │
│  │                                                                  │     │
│  │  ┌──────────────────────────────────────────────────────┐        │     │
│  │  │ 🍃 MongoDB Database                                  │        │     │
│  │  │  • Users Collection                                  │        │     │
│  │  │  • Orders Collection                                 │        │     │
│  │  │  • Stores Collection                                 │        │     │
│  │  │  • Products Collection                               │        │     │
│  │  │  • Cart Collection                                   │        │     │
│  │  │  • Transactions Collection                           │        │     │
│  │  └──────────────────────────────────────────────────────┘        │     │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │ 💳 Payment Aggregator (Separate Service)                          │    │
│  │                                                                   │     │
│  │  • Base URL: http://196.189.44.60/                                │     │
│  │                                                                   │     │
│  │  • Handles payment gateway integrations                           │     │
│  │  • Payment processing endpoints                                   │     │
│  │  • Telebirr, Chapa, EthSwitch, Amole, etc.                        │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                            │
└───────────────────┬────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TIER 3: FIREBASE & CLOUD SERVICES                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 🔥 Firebase Services (Project: zmall-184809)                          │  │
│  │                                                                       │  │
│  │  Active Services (In Use):                                            │  │
│  │  ┌────────────────┐  ┌────────────────────┐                          │  │
│  │  │ 🔔 Cloud       │  │ 📊 Analytics       │                          │  │
│  │  │    Messaging   │  │    + Events        │                          │  │
│  │  │    (FCM)       │  │                    │                          │  │
│  │  └────────────────┘  └────────────────────┘                          │  │
│  │                                                                       │  │
│  │  Integrated but Not Used:                                            │  │
│  │  ┌────────────────────┐                                              │  │
│  │  │ 🔗 Dynamic Links   │                                              │  │
│  │  │    (Configured)    │                                              │  │
│  │  └────────────────────┘                                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                    ▲
                    │
                    │
┌───────────────────┴──────────────────────────────────────────────────────────┐
│                    MOBILE APPLICATION LAYER                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 📱 ZMall Flutter App (v3.2.3+340)                                   │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │ PRESENTATION LAYER (lib/)                                    │  │    │
│  │  │                                                               │  │    │
│  │  │  Feature Modules:                                            │  │    │
│  │  │  • Splash & Onboarding    • Shopping Cart                    │  │    │
│  │  │  • Login/Register (OTP)   • Checkout & Orders                │  │    │
│  │  │  • Home (Local Market)    • Delivery Tracking                │  │    │
│  │  │  • Global Marketplace     • Wallet (Borsa)                   │  │    │
│  │  │  • Store Browsing         • Profile Management               │  │    │
│  │  │  • Product Details        • Event Booking                    │  │    │
│  │  │  • Search                 • World Cup Special                │  │    │
│  │  │  • Notifications          • AliExpress Integration           │  │    │
│  │  │  • Courier Service        • Support Chat                     │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │ BUSINESS LOGIC LAYER                                         │  │    │
│  │  │                                                               │  │    │
│  │  │  • service.dart - Main service handler                       │  │    │
│  │  │  • core_services.dart - API integration                      │  │    │
│  │  │  • biometric_services/ - Biometric auth                      │  │    │
│  │  │  • firebase_core_services.dart - Firebase utils              │  │    │
│  │  │  • State Management (Provider)                               │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │ DATA LAYER                                                   │  │    │
│  │  │                                                               │  │    │
│  │  │  Models: User, Cart, Order, Store, Product, Language, etc.   │  │    │
│  │  │                                                               │  │    │
│  │  │  Local Storage:                                              │  │    │
│  │  │  • SharedPreferences - App data, cart, cached content        │  │    │
│  │  │  • Flutter Secure Storage - Encrypted biometric credentials  │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │ SECURITY & AUTHENTICATION                                    │  │    │
│  │  │                                                               │  │    │
│  │  │  • Biometric Auth (Face ID, Touch ID, Fingerprint)           │  │    │
│  │  │  • OTP Verification (SMS)                                    │  │    │
│  │  │  • Multi-Account Support                                     │  │    │
│  │  │  • Encrypted Credential Storage                              │  │    │
│  │  │  • Device Token Management                                   │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  Platforms: iOS (15.0+) | Android (SDK 36)                          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Backend API Endpoints Overview

### Base URLs:

- **Production**: `http://196.188.187.43:8000`
- **Test**: `http://196.189.44.49:7000`
- **Payment Aggregator**: `http://196.189.44.60/`

### Key API Categories:

#### 🔐 Authentication & User Management

```
POST   /api/user/login
POST   /api/user/generate_otp_at_login
POST   /api/user/verify_otp
POST   /api/user/send_otp
POST   /api/user/forgot_password
POST   /api/user/reset_password
GET    /api/user/get_detail
PUT    /api/user/update
POST   /api/user/logout
```

#### 🛒 Shopping & Cart

```
GET    /api/user/get_delivery_list_for_nearest_city
POST   /api/user/add_item_in_cart
POST   /api/user/add_item_in_cart_new
POST   /api/user/clear_cart
POST   /api/user/apply_promo_code
GET    /api/user/get_order_cart_invoice
```

#### 📦 Order Management

```
POST   /api/user/create_order
GET    /api/user/get_orders
GET    /api/user/order_history
GET    /api/user/order_history_detail
GET    /api/user/get_order_status
GET    /api/user/show_invoice
POST   /api/user/user_cancel_order
```

#### 💳 Payment & Wallet

```
POST   /api/user/pay_order_payment
POST   /api/user/add_wallet_amount
POST   /api/user/add_wallet_amount_new
POST   /api/user/transfer_wallet_amount
GET    /api/admin/get_wallet_history
POST   /admin/pay_payment_etswitch
POST   /admin/pay_payment_ettacard
```

#### 🏪 Store & Products

```
GET    /api/user/get_store_list_by_company
GET    /api/user/get_company_list
GET    /api/user/get_promotion_item
GET    /api/user/get_promotion_store
GET    /api/user/search_item_global
GET    /api/user/user_get_store_product_item_list
```

#### 🚚 Delivery & Location

```
GET    /api/user/get_provider_location
GET    /api/user/get_courier_order_invoice
GET    /api/store/get_vehicle_list
```

#### ⭐ Rating & Reviews

```
GET    /api/user/user_get_store_review_list
POST   /api/user/rating_to_store
POST   /api/user/rating_to_provider
```

#### 🌍 AliExpress Integration

```
GET    /admin/aliexpress_product
GET    /admin/aliexpress_product_detail
POST   /admin/aliexpress_creat_order
```

#### 🎟️ Events & Games

```
GET    /api/admin/get_user_event_history
POST   /api/admin/generate_ticket_invoice
GET    /api/admin/get_game_user_history
POST   /api/admin/predict_game
```

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA FLOW DIAGRAM                           │
└─────────────────────────────────────────────────────────────────┘

  Mobile App (Flutter)
       │
       ├──────────────────────────────────────────┐
       │                                           │
       │                                           ▼
       │                                    ┌──────────────┐
       │                                    │   Firebase   │
       │                                    │   Services   │
       │                                    │              │
       ├──────────▶ Analytics               │ • Analytics  │
       │            Notifications           │ • FCM        │
       │                                    └──────────────┘
       │
       ├──────────▶ ZMall Server (Main Backend)
       │            Production: http://196.188.187.43:8000
       │            Test: http://196.189.44.49:7000
       │                 │
       │                 ├─▶ /api/user/*        (User operations)
       │                 ├─▶ /api/admin/*       (Admin operations)
       │                 ├─▶ /api/store/*       (Store operations)
       │                 │
       │                 └─▶ MongoDB Database
       │                     • Users, Orders, Stores, Products
       │                     • Cart, Transactions, etc.
       │
       ├──────────▶ Payment Aggregator (Separate Service)
       │            Base URL: http://196.189.44.60/
       │            • Handles: Telebirr, Chapa, EthSwitch, Amole, etc.
       │
       ├──────────▶ Google Services
       │            • Maps API
       │            • OAuth
       │
       ├──────────▶ Facebook
       │            • App Events Analytics
       │
       │
       └──────────▶ Local Storage
                    • SharedPreferences (app data, cart, cache)
                    • Secure Storage (encrypted credentials)
```

---

## Security Architecture

### 🔒 Security Layers

#### 1. **Network Security**

- HTTPS for all API communications
- SSL/TLS certificate pinning
- Firebase security rules
- Request timeout management (10-20s)

#### 2. **Authentication Security**

- **Multi-factor:**
  - OTP via SMS
  - Biometric (Face ID, Touch ID, Fingerprint)
- **Token Management:**
  - Device token registration
  - Server token validation
  - Token expiration handling (error 2000)

#### 3. **Data Security**

- **Encryption:**
  - Fernet encryption for sensitive data
  - AES encryption via `encrypt` package
- **Secure Storage:**
  - Android: EncryptedSharedPreferences
  - iOS: Keychain via Flutter Secure Storage
- **Encrypted Fields:**
  - User passwords
  - Biometric credentials
  - Payment information

#### 4. **Platform Security**

- **Permissions Management:**
  - Camera (QR scanning)
  - Location (store proximity)
  - Biometric (Face ID/Touch ID)
  - Photo library
- **Background Security:**
  - Secure background fetch
  - Notification encryption

#### 5. **Payment Security**

- Native SDK integration (Telebirr)
- PCI-compliant payment gateways
- No card data storage on device
- Secure payment token handling

---

## Infrastructure Details

### 📱 Mobile App Infrastructure

#### **iOS Configuration**

- **Bundle ID**: `com.zmall.user`
- **Min iOS**: 15.0
- **URL Schemes**:
  - `zmallreturn` - Payment callbacks
  - `fb1050203588837738` - Facebook
  - `customscheme` - Deep links

#### **Android Configuration**

- **Application ID**: `com.zmall.user`
- **Namespace**: `com.enigma.zmall`
- **Target SDK**: 36
- **Min SDK**: 21 (likely)
- **Compile SDK**: 36
- **MultiDex**: Enabled
- **NDK Version**: 29.0.14206865

### 🔥 Firebase Configuration

**Project**: `zmall-184809`

**Services Enabled:**

- **Cloud Messaging (FCM)** - Active (push notifications)
- **Analytics** - Active (event tracking and user analytics)

**Services Configured but Not Used:**

- **Dynamic Links** - Integrated but not actively used

**API Keys:**

- **Android**: `AIzaSyDFfRtPeakrhsHOxOaZOYpPQM8klHC6Y80`
- **iOS**: `AIzaSyDAgZScAJfUHxahi_n4OpuI8HrTHVlirJk`

### 🌐 Google Services

**Google Maps API Keys:**

- **Android**: `AIzaSyBzMHLnXLbtLMi9rVFOR0eo5pbouBtxyjg`
- **iOS**: `AIzaSyDAgZScAJfUHxahi_n4OpuI8HrTHVlirJk`

**Google OAuth**: Configured for sign-in

### 📘 Facebook Integration

- **App ID**: `1050203588837738`
- **Client Token**: `3167abc63899705752c31bea73fae744`
- **Services**:
  - App Events
  - Analytics
  - Social Login (optional)

---

## Technology Stack Summary

### Frontend (Mobile)

- **Framework**: Flutter 3.2.3
- **Language**: Dart (SDK >=3.9.0)
- **State Management**: Provider
- **UI Libraries**: Material Design, Cupertino Icons
- **Networking**: HTTP package
- **Storage**: SharedPreferences, Secure Storage

### Backend

- **API Type**: RESTful
- **Architecture**:
  - **ZMall Server**: Main backend
  - **Payment Aggregator**: Separate payment processing service
- **Database**: MongoDB
- **Hosting**:
  - Production: http://196.188.187.43:8000
  - Test: http://196.189.44.49:7000
  - Payment: http://196.189.44.60/

### DevOps & Infrastructure

- **Version Control**: Git
- **CI/CD**: Automated builds (configured)
- **Release Management**: Versioned releases (v3.2.3+340)
- **Direct Connection**: Mobile app connects directly to servers
- **Server Environments**: Production and Test instances

### Third-Party Services

- **Payment**: 10+ payment gateway integrations
- **Maps**: Google Maps Platform
- **Analytics**: Firebase + Facebook
- **Messaging**: Firebase Cloud Messaging
- **Ads**: nedajmadeya.com

---

## Special Features

### 🎯 Unique Capabilities

1. **Proximity-Based Ordering**

   - Geolocation-based store discovery
   - Real-time delivery tracking
   - Courier proximity matching

2. **Production & Test Environments**

   - Production server (http://196.188.187.43:8000)
   - Test server (http://196.189.44.49:7000)
   - Payment aggregator (http://196.189.44.60/)
   - Multiple payment methods

3. **Advanced Authentication**

   - Biometric multi-account support
   - OTP via SMS
   - Social login (Facebook)
   - Secure credential storage

4. **Comprehensive E-commerce**

   - Local marketplace
   - Global marketplace (AliExpress)
   - Event ticket booking
   - Game predictions
   - Wallet system

5. **Real-time Features**
   - Live order tracking
   - Push notifications
   - In-app messaging
   - Support chat

---

## Performance Optimizations

### 📊 App Performance

1. **Caching Strategy**

   - Local caching of categories
   - Product item caching
   - Store data caching
   - Image caching

2. **Loading Optimizations**

   - Shimmer loading effects
   - Lazy loading for lists
   - Pagination for large datasets
   - Staggered grid views

3. **Network Optimizations**

   - Request timeouts (10-20s)
   - Retry mechanisms
   - Offline data access
   - Background sync

4. **Build Optimizations**
   - MultiDex enabled
   - ProGuard/R8 (Android)
   - App size optimization
   - Code splitting

---

## Deployment Architecture

### 🚀 Release Pipeline

```
Development
    │
    ├─▶ Flutter Build (iOS)
    │   ├─ CocoaPods dependency resolution
    │   ├─ Xcode build
    │   └─ TestFlight deployment
    │
    └─▶ Flutter Build (Android)
        ├─ Gradle build
        ├─ App signing (key.properties)
        ├─ Bundle generation (.aab)
        └─ Play Store deployment
```

### 🌍 Server Deployment

```
Mobile App (Direct Connection)
    │
    ├─▶ ZMall Server (Production)
    │   └─ http://196.188.187.43:8000
    │       • REST API endpoints
    │       • MongoDB database
    │
    ├─▶ ZMall Server (Test)
    │   └─ http://196.189.44.49:7000
    │       • REST API endpoints
    │       • MongoDB database
    │
    └─▶ Payment Aggregator
        └─ http://196.189.44.60/
            • Payment gateway integrations
            • Payment processing service
            • Payment endpoints (/admin/pay_payment_*)
```

---

## Monitoring & Analytics

### 📈 Analytics Implementation

1. **Firebase Analytics**

   - Automatic event tracking
   - Custom event logging
   - User property tracking
   - Conversion tracking

2. **Facebook Analytics**

   - App launch events
   - App activate/deactivate
   - Custom business events
   - User behavior tracking

3. **Performance Monitoring**
   - Crash reporting (likely)
   - API response time tracking
   - User session tracking
   - Network performance

---

## Data Models

### 👤 Core Data Structures

**User Model**: Phone, name, email, country, device token, wallet balance, biometric settings

**Cart Model**: Items, quantities, store info, pricing, delivery options

**Order Model**: Order ID, items, status, payment info, delivery details, tracking

**Store Model**: Store ID, name, location, hours, categories, ratings

**Product Model**: Product ID, name, price, images, description, stock, store

**Language Model**: Multi-language support structure

---

## API Response Patterns

### 📡 Standard Response Format (Inferred)

```json
{
  "success": true/false,
  "code": 1000,  // Success: 1000, Token expired: 2000
  "message": "Success message",
  "data": { ... }
}
```

### Error Handling

- **Code 1000**: Success
- **Code 2000**: Token expired/invalid
- **Timeout**: 10-20 seconds based on operation
- **Retry Logic**: Implemented for critical operations

---

## Conclusion

ZMall is a **comprehensive e-commerce platform** with:

- ✅ Production and Test environments
- ✅ 10+ payment gateway integrations
- ✅ Advanced biometric authentication
- ✅ Real-time delivery tracking
- ✅ Event booking system
- ✅ International shopping (AliExpress)
- ✅ Wallet and transfer system
- ✅ Enterprise-grade security
- ✅ MongoDB database
- ✅ Firebase integration for analytics and messaging

The architecture follows a **simplified microservices pattern** with:

- **Mobile Application Layer**: Flutter app with direct server connections
- **ZMall Server**: Main backend (Production & Test instances)
- **Payment Aggregator**: Dedicated payment processing service
- **MongoDB Database**: Document-based data storage
- **Firebase Services**: FCM (push notifications) and Analytics
- **External Services**: Google Maps, Facebook Analytics, Payment Gateways

This design allows for **scalability, maintainability, and reliability** with:

- Direct client-to-server communication
- Separate production and test environments
- Independent payment processing infrastructure
- Flexible NoSQL database (MongoDB)
