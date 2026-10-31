# BudgetMe

A native iPhone app for keeping on top of credit card payments, recurring bills and card credits. Built with SwiftUI and SwiftData, and synced through your own iCloud account.

## What's in it

| Tab | What it does |
| --- | --- |
| **Due** | This month's card payments and bills, grouped by the payday that covers them (1st and 15th by default). Tap the circle or swipe right to mark one paid. You can step forward to next month and pay early. |
| **Credits** | Monthly, quarterly, half-yearly and yearly credits (Uber, Resy, DoorDash, hotel credits…). Each one **resets on its own** when its period rolls over, so you never have to uncheck boxes. Shows which credits reset within a week. The calendar button opens **Credit History**: every credit used this year, card by card, with totals. Tap a past month to fill in credits you used before you had the app. |
| **Best Card** | Pick what you're buying (Dining, Groceries, Hotels…) and your cards are ranked by what they earn there. Hotels, flights and car rentals also count a card's general travel rate. The filter button at the top has **Include Portal Bookings** (rates that need Chase Travel, Amex Travel and similar) and **No Foreign Transaction Fees** (for spending abroad). When two cards earn the same multiplier, the one whose points are worth more wins (each card has an editable point value, estimated from its name). |
| **Wallet** | Your cards as a Wallet-style stack. Tap one for its due date, earning rates, credits and perks, and to edit it. Add a card's annual fee to see how much of it this year's credits have earned back, there and in Credit History. |

Settings (the gear in Wallet) has your paydays, payment reminders (how many days before, what time, and an optional second reminder on the due date), Appearance (Automatic, Light or Dark), iCloud status, and **Load Cards from My Notes**, which fills in everything from the original notes in one tap. Each card or bill can also have its own reminder when you edit it.

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
