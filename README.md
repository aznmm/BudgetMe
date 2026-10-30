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
2. Select the **BudgetMe** target → **Signing & Capabilities** → choose your **Team**.
3. If Xcode says the bundle ID is taken, change it (for example `com.yourname.BudgetMe`). Then update the iCloud container to match, as described below.
4. Pick your iPhone or a simulator and press **Run**.
5. On first launch, tap **Load My Cards from Notes**.

### iCloud sync

Syncing uses CloudKit, which requires a paid **Apple Developer Program** membership.

- The container is `iCloud.com.aznmm.BudgetMe`. If you change the bundle ID, go to **Signing & Capabilities → iCloud** and select or create the matching container. Then update the same ID in `Config/BudgetMe.entitlements` and the `CloudKitContainer` key in `Config/Info.plist`.
- To try the app without a paid account, remove the **iCloud** and **Push Notifications** capabilities and clear the `CloudKitContainer` value in `Config/Info.plist`. Your data then stays on that device only, and no code changes are needed.
- Load the starter data on **one** device only. Your other devices receive it through iCloud.

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
