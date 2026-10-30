# BudgetMe

A native iPhone app for keeping on top of credit card payments, recurring bills and card credits. Built with SwiftUI and SwiftData, and synced through your own iCloud account.

## What's in it

| Tab | What it does |
| --- | --- |
| **Due** | This month's card payments and bills, grouped by the payday that covers them (1st and 15th by default). Tap the circle or swipe right to mark one paid. You can step forward to next month and pay early. |
| **Credits** | Monthly, quarterly, half-yearly and yearly credits (Uber, Resy, DoorDash, hotel credits…). Each one **resets on its own** when its period rolls over, so you never have to uncheck boxes. Shows which credits reset within a week. |
| **Best Card** | Pick what you're buying (Dining, Groceries, Hotels…) and your cards are ranked by what they earn there. Hotels, flights and car rentals also count a card's general travel rate. |
| **Wallet** | Your cards as a Wallet-style stack. Tap one for its due date, earning rates, credits and perks, and to edit it. |

Settings (the gear in Wallet) has your paydays, 9 AM payment reminders, iCloud status, and **Load Cards from My Notes**, which fills in everything from the original notes in one tap.

## Running it

You'll need a Mac with **Xcode 16 or later**. The app runs on iOS 17 or later.

1. Clone the repo and open `BudgetMe.xcodeproj`.
2. Select the **BudgetMe** target → **Signing & Capabilities** → choose your **Team** (a free Apple ID works).
3. If Xcode says the bundle ID is taken, change it to something unique, e.g. `com.yourname.BudgetMe`.
4. Plug in your iPhone, select it as the run destination and press **Run**.
5. On first launch, tap **Load My Cards from Notes**.

With a free Apple ID the app works for 7 days at a time. Run it from Xcode again to renew it; your data stays put.

### Turning on iCloud sync (paid developer account)

The project is set up for on-device storage so it builds with a free account. To sync across devices with a paid **Apple Developer Program** membership:

1. In **Signing & Capabilities**, add **iCloud** (tick **CloudKit**, add container `iCloud.<your bundle ID>`) and **Push Notifications**. `Config/BudgetMe.entitlements` has the expected values for reference.
2. Put the same container ID in the `CloudKitContainer` key of `Config/Info.plist` (used for the sync status in Settings).

No code changes are needed: the app syncs automatically when the iCloud capability is present. Existing data on the phone uploads on first launch, so only load the starter data on one device.

## Project layout

```
BudgetMe/
  BudgetMeApp.swift          App entry and SwiftData + CloudKit container
  Models/                    CreditCard, Benefit (credits), Bill, periods, rewards, card finishes, starter data
  Services/                  Payment reminders
  Views/
    Due/  Credits/  Rewards/  Cards/  Components/
    RootView.swift           Tab bar
    SettingsView.swift
Config/                      Info.plist additions and iCloud entitlements
```

The source folder is a synchronized group, so any new `.swift` file you add under `BudgetMe/` is picked up automatically.
