Rooted is an iOS app for Baytown, Texas. It turns everyday eco habits and local volunteering into a garden and a neighborhood you can watch grow. Recycle, compost, save water or volunteer, and your yard and the street behind it come to life. Stop showing up and things start to wilt and go quiet.

  Built with SwiftUI as a Congressional App Challenge entry.

  ## How it works

  ### Do Good: eco habits
  There are six daily tasks: **Recycle Something**, **Compost Food Scraps**, **Reusable Bag/Bottle**, **Donate an
  Item**, **Reduce Water Use** and **Walk or Bike Instead of Drive**.

  - Each task earns EcoCoins. Repeating a task on the same day earns a bonus.
  - You can attach a photo as proof.
  - Doing every task at least once in a day keeps your **streak** going.
  - Each task has a Baytown tip and a link to the official page for it, such as the Baytown Green Center, curbside
  recycling, the Goose Creek Trail or Harris County Transit.

  ### Do Good: volunteering
  You can log hours at real Baytown programs, including the Baytown Animal Shelter, Sterling Municipal Library teen
  volunteers, the Eddie V. Gray Wetlands Center (E.P.I.C. Teen Volunteers), the Baytown Nature Center, Baytown
  Habitat for Humanity and the Houston Food Bank.

  Each kind of volunteering builds one place on your street (Animal Shelter, Library, Nature Center, Food Bank or
  Neighborhood). Each place grows from **Empty Lot → Under Construction → Open → Thriving** at 1, 4 and 10 hours. A
  place stays lively for 14 days after you last volunteered for it.

  ### Community: your garden and street
  - Spend coins in the **Shop** on seedlings, flowers, trees, bluebonnets, butterflies, bird houses, compost bins and
  rain barrels, then drag them anywhere in your yard.
  - Every item grows through four stages when you look after it. Neglected items wilt after about 18 hours.
  - Composting and saving water in real life tend your Compost Bins and Rain Barrels for free.
  - Eco habits add green upgrades to the street, like bike racks, recycling bins and a community garden.
  - All tasks and volunteer hours count toward your **Community Level**, which adds trees, streetlights, flags and
  eventually a festival.
  - A **weekly challenge** asks for a mix of eco tasks and volunteering.
  - A **community map** (MapKit) shows the Baytown places the app links to.

  ### Your impact
  The About screen totals your estimated impact:

  | Stat | How it's estimated | Source |
  | --- | --- | --- |
  | CO₂ avoided | Each walk or bike trip = a 2-mile car trip avoided, at about 400 g CO₂ per mile | EPA average 
  passenger vehicle emissions |
  | Water saved | Each water task = a shower 2 minutes shorter, at 2.5 gallons per minute | Federal showerhead  standard (EPA WaterSense) |
  | Kept from landfill | Each recycle, compost, reuse or donate task = 1 item | — |                            | Volunteer hours | Hours you log | — |

| Kept from landfill | Each recycle, compost, reuse or donate task = 1 item | — |
| Volunteer hours | Hours you log | — |

### Reminders
An optional reminder at 6 PM to finish your tasks, and an alert when something in your garden needs care.

## Privacy

All data stays on the device. There's no server and no third-party SDK.

- **Account:** one local account. The password is never stored. Only a salted, iterated SHA-256 hash is saved in the iOS Keychain.
- **Progress:** tasks, garden and volunteer log are saved to `UserDefaults`.
- **Proof photos:** resized to 1200 px at most and saved in the app's Application Support folder.

## Requirements

- Xcode 16.4 or later (needed for the iOS 18.5 SDK)
- iOS 18.5 or later (iPhone and iPad)
- No external dependencies. The app uses only Apple frameworks: SwiftUI, MapKit, PhotosUI, UserNotifications, CryptoKit and Security.

## Running it

1. Open `EcoGarden.xcodeproj` in Xcode.
2. Choose the **EcoGarden** scheme and an iPhone simulator or device.
3. Press **Run** (⌘R). If you're running on a real device, set your own team under *Signing & Capabilities*.
4. Create an account on the welcome screen to start.

## Project structure

```
EcoGarden/
├── EcoGardenApp.swift      App entry point
├── ContentView.swift       Welcome vs. main tabs, celebration banners
├── Appstate.swift          All app state, rules (coins, streaks, levels) and saving
├── Models.swift            Tasks, garden items, volunteer programs, Baytown places
├── AccountStore.swift      Local account with a Keychain-stored password hash
├── ProofStore.swift        Saving and loading proof photos
├── Reminders.swift         Local notifications
├── WelcomeView.swift       Sign up / log in
├── DoGoodView.swift        Do Good tab (habits + volunteer)
├── TaskListView.swift      Eco task list and photo proof
├── VolunteerView.swift     Volunteer programs and hour logging
├── GardenView.swift        Community tab: yard, street and buildings
├── CommunityMapView.swift  Map of Baytown places
├── ShopView.swift          Shop
├── InfoView.swift          About, impact, reminders, account
├── PlantArt.swift          Drawn garden item artwork
├── TownArt.swift           Drawn street and building artwork
└── Theme.swift             Colors, fonts and shared styles
```

The app's display name is **Rooted**. The Xcode project and target are still named `EcoGarden`.
Tip: Press Option+Enter to send a multi-line message
