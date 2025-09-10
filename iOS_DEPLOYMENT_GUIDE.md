# 📱 iOS Deployment Guide for Drivrr Apps

## 🔧 Prerequisites

### 1. Hardware Requirements
- **macOS Computer** (MacBook, iMac, or Mac Mini)
- **iPhone/iPad** for testing
- **Lightning/USB-C Cable** to connect device

### 2. Software Requirements
- **Xcode** (latest version from App Store)
- **Flutter SDK** (3.35.3 or later)
- **Apple Developer Account** (free or paid)

## 📱 Step-by-Step iOS Deployment

### Step 1: Install Xcode
```bash
# Install from App Store or run:
xcode-select --install
```

### Step 2: Install Flutter on Mac
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

### Step 3: Setup iOS Development
```bash
# Accept Xcode license
sudo xcodebuild -license accept

# Install iOS simulator
open -a Simulator

# Check iOS setup
flutter doctor --verbose
```

### Step 4: Configure Bundle Identifiers

#### Customer App:
```bash
cd customer_app/ios
open Runner.xcworkspace
```

In Xcode:
1. Select **Runner** project
2. Go to **Signing & Capabilities**
3. Set **Bundle Identifier**: `com.drivrr.customer`
4. Select your **Team** (Apple Developer Account)
5. Enable **Automatically manage signing**

#### Driver App:
```bash
cd driver_app/ios  
open Runner.xcworkspace
```

In Xcode:
1. Select **Runner** project
2. Go to **Signing & Capabilities**
3. Set **Bundle Identifier**: `com.drivrr.driver`
4. Select your **Team** (Apple Developer Account)
5. Enable **Automatically manage signing**

### Step 5: Build and Deploy

#### Option A: Direct Device Installation
```bash
# Connect iPhone via cable
# Trust computer on iPhone

# Customer App
cd customer_app
flutter run -d [device-id]

# Driver App  
cd driver_app
flutter run -d [device-id]
```

#### Option B: Build for Distribution
```bash
# Customer App
cd customer_app
flutter build ios --release

# Driver App
cd driver_app  
flutter build ios --release
```

#### Option C: Archive for App Store
1. Open `customer_app/ios/Runner.xcworkspace` in Xcode
2. Select **Generic iOS Device** or connected device
3. Go to **Product** → **Archive**
4. Upload to App Store Connect
5. Repeat for driver app

## 🔐 Apple Developer Account Setup

### Free Account (Development Only)
- Sign in with Apple ID in Xcode
- Limited to 7 days app installation
- Cannot publish to App Store

### Paid Account ($99/year)
- Full development capabilities  
- 1 year app installation
- App Store publishing
- TestFlight distribution

## 📋 Required Permissions (Already Configured)

Both apps include these iOS permissions:
- ✅ Location (When In Use)
- ✅ Location (Always - for driver tracking)
- ✅ Camera (Profile photos)
- ✅ Photo Library (Profile selection)
- ✅ Microphone (Voice messages)
- ✅ Contacts (Emergency contacts)

## 🚨 Common Issues & Solutions

### Issue 1: Code Signing Error
**Solution:**
```bash
# In Xcode, go to Signing & Capabilities
# Select your Apple Developer Team
# Enable "Automatically manage signing"
```

### Issue 2: Provisioning Profile Error
**Solution:**
```bash
# Delete old profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
# Regenerate in Xcode
```

### Issue 3: Device Not Recognized
**Solution:**
```bash
# Check connected devices
flutter devices
# Trust computer on iPhone
# Enable Developer Mode in iPhone Settings
```

### Issue 4: Build Failures
**Solution:**
```bash
# Clean build
flutter clean
cd ios && rm -rf Pods Podfile.lock
flutter pub get
cd ios && pod install
flutter build ios
```

## 🎯 Testing Checklist

### Before Release:
- [ ] Test on multiple iOS versions (iOS 12+)
- [ ] Test on different screen sizes (iPhone SE, Pro Max)
- [ ] Test location permissions
- [ ] Test offline scenarios
- [ ] Test WebSocket connections
- [ ] Test ride flow end-to-end
- [ ] Test both customer and driver apps together

## 📦 Distribution Options

### 1. Development Distribution
- Install directly on devices (up to 100 devices)
- Valid for 1 year with paid account

### 2. TestFlight Distribution  
- Beta testing with up to 10,000 users
- Requires paid Apple Developer account
- Automatic updates

### 3. App Store Distribution
- Public release
- Requires app review approval
- Global distribution

## 🔄 Automated Deployment

### GitHub Actions (Recommended)
- Use provided `.github/workflows/ios-build.yml`
- Automatic builds on code push
- Artifacts available for download

### Codemagic (Alternative)
- Use provided `codemagic.yaml`
- Cloud-based iOS builds
- No Mac required

## 📞 Support

If you encounter issues:
1. Check `flutter doctor` output
2. Verify Xcode configuration
3. Ensure Apple Developer account is active
4. Test with simple Flutter app first

---

**🎉 Once deployed, your Drivrr apps will run natively on iOS with all the professional features we implemented!**
