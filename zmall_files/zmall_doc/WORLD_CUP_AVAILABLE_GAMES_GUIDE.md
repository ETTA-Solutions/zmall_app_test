# World Cup — Available Games & Team Container Deep Guide

> Files covered:
> - `lib/world_cup/available_games.dart`
> - `lib/world_cup/components/team_container_widget.dart`

---

## Table of Contents

1. [Overview](#1-overview)
2. [available_games.dart — Full Breakdown](#2-available_gamesdart--full-breakdown)
   - [Widget Type & State Variables](#21-widget-type--state-variables)
   - [Lifecycle & Startup Order](#22-lifecycle--startup-order)
   - [API 1 — Get Games](#23-api-1--get-games)
   - [API 2 — Get User Predictions](#24-api-2--get-user-predictions)
   - [Game Card Decision Tree](#25-game-card-decision-tree)
   - [Logo Resolution — The Automatic Match](#26-logo-resolution--the-automatic-match)
   - [Score vs Time Display](#27-score-vs-time-display)
   - [Game Status Logic](#28-game-status-logic)
   - [Banner Image](#29-banner-image)
   - [Prediction Lock](#210-prediction-lock)
   - [Empty State](#211-empty-state)
   - [Refresh Button](#212-refresh-button)
3. [team_container_widget.dart — Full Breakdown](#3-team_container_widgetdart--full-breakdown)
   - [What It Is](#31-what-it-is)
   - [The Automatic Match — Exact Mechanism](#32-the-automatic-match--exact-mechanism)
   - [Full Widget Annotated](#33-full-widget-annotated)
   - [Where It Is Used](#34-where-it-is-used)
   - [Limitation](#35-limitation)
4. [How Both Files Connect](#4-how-both-files-connect)
5. [Data Flow — End to End](#5-data-flow--end-to-end)
6. [Key Gotchas](#6-key-gotchas)

---

## 1. Overview

The World Cup prediction feature has two main tabs inside `WorldCupScreen`:

| Tab | File | Purpose |
|---|---|---|
| Available Games | `available_games.dart` | Fetches and lists all matches. User taps to predict. |
| My Predictions | `my_prediction.dart` | Shows the user's submitted predictions. |

`team_container_widget.dart` is a small reusable widget used inside `predict_screen.dart` to display each team (logo + name) when the user opens a match to make a prediction.

---

## 2. `available_games.dart` — Full Breakdown

### 2.1 Widget Type & State Variables

`AvailableGames` is a `StatefulWidget` because it needs to fetch data, show a loading spinner, and re-render when data arrives.

```dart
class _AvailableGamesState extends State<AvailableGames> {
  bool _isLoading = false;    // true while any API call is in progress
  var games;                  // raw list from API — null until first load
  var userPredictions;        // user's prediction history from API
  var userData;               // user object read from local storage (for user _id)
}
```

- `games` starts as `null`. The UI checks `games != null && games.length > 0` before rendering the list.
- `userPredictions` is used to know which games the user has already predicted, so those cards can be hidden.

---

### 2.2 Lifecycle & Startup Order

When the screen opens, `initState()` fires:

```
initState()
    │
    ├── _getGames()
    │       └── POST /api/admin/get_game_user_history
    │               └── setState(games = data['games'])
    │
    └── getUser()
            └── Service.read('user')   ← reads from local storage
                    └── setState(userData = data)
                            └── _getPredictions()
                                    └── POST /api/admin/get_prediction_history
                                            └── setState(userPredictions = data)
```

> `_getPredictions()` is only called AFTER `getUser()` completes because it needs `userData['user']['_id']` to filter predictions for the current user.

Both `_getGames()` and `_getPredictions()` are also called again:
- When the user taps the **refresh FAB**
- When the user returns from `PredictScreen` (via `.then((_) { _getGames(); _getPredictions(); })`)

---

### 2.3 API 1 — Get Games

**Location:** `getGames()`, line 272

```
Method:   POST
Endpoint: {baseUrl}/api/admin/get_game_user_history
Headers:  Content-Type: application/json
Body:     {}
Timeout:  15 seconds
```

**Expected response:**

```json
{
  "success": true,
  "games": [
    {
      "_id": "64f2a...",
      "type": "Game Week 1",
      "home_team": "CHE",
      "away_team": "LIV",
      "home_team_logo": "https://cdn.example.com/che.png",
      "away_team_logo": null,
      "game_time": "2025-08-18T18:30:00.000Z",
      "stadium": "Stamford Bridge",
      "is_finished": false,
      "home_score": 0,
      "away_score": 0,
      "game_banner": "https://cdn.example.com/banner.jpg"
    }
  ]
}
```

If the API returns `success: false` or the call fails, `games` stays `null` and the empty state is shown.

---

### 2.4 API 2 — Get User Predictions

**Location:** `getPredictions()`, line 325

```
Method:   POST
Endpoint: {baseUrl}/api/admin/get_prediction_history
Headers:  Content-Type: application/json
Body: {
  "search_field": "user_detail._id",
  "search_value": "<logged-in user's _id>",
  "start_date": "",
  "end_date": ""
}
Timeout:  15 seconds
```

**Expected response:**

```json
{
  "success": true,
  "scores": [
    { "game_id": "64f2a...", "home_score": 2, "away_score": 1 }
  ]
}
```

This is used to check whether the user has already predicted a given game.

---

### 2.5 Game Card Decision Tree

For every game returned by the API, this logic runs inside `ListView.builder`:

```
For each game in games list:
│
├── Step 1: Has the user already predicted this game?
│     userPredictions['scores'].any(p => p['game_id'] == game['_id'])
│
│     AND is the game still ongoing (is_finished == false)?
│           → return SizedBox.shrink()   ← card invisible, slot preserved in list
│
├── Step 2: Calculate game time status
│     now = DateTime.now().toUtc() + 3 hours
│     gameTime = DateTime.parse(game['game_time']).toLocal()
│
│     isLive            = now > gameTime AND now < gameTime + 125min
│     isGameTimeFinished = now > gameTime + 125min
│
├── Step 3: Build status string
│     game['is_finished'] == true  →  "FT"
│     isGameTimeFinished == true   →  "FT"
│     isLive == true               →  "Live"
│     otherwise                   →  "NS"   (Not Started)
│
└── Step 4: Render MatchRow card with all resolved data
```

> The 125-minute window is used because a football match is 90 minutes + stoppage time + possible extra time.

---

### 2.6 Logo Resolution — The Automatic Match

The app tries three sources for a team logo, in priority order:

```
Priority 1 — API network URL
    game['home_team_logo'] != null
        → use CachedNetworkImage(game['home_team_logo'])

Priority 2 — Local asset (automatic match by team name)
    game['home_team_logo'] == null
        → "images/pl_logos/${game['home_team'].toLowerCase()}.png"
        → e.g.  "CHE"  →  "images/pl_logos/che.png"  ✅

Priority 3 — Error fallback inside LogoContainer
    If the network image fails to load
        → errorLogoAsset = "images/pl_logos/${game['home_team'].toLowerCase()}.png"
```

**Code (lines 166–172 and 197–200):**

```dart
homeClubLogo:
    game['home_team_logo'] ??
    "images/pl_logos/${game['home_team'].toLowerCase()}.png",

homeErrorClubLogo:
    "images/pl_logos/${game['home_team'].toString().toLowerCase()}.png",
```

**How the automatic match works:**

```
API sends  →  game['home_team'] = "CHE"
Code does  →  "CHE".toLowerCase()  =  "che"
Builds     →  "images/pl_logos/che.png"
Result     →  Chelsea badge appears — no manual mapping needed
```

The `images/pl_logos/` folder contains 71 PNG files. As long as the API team abbreviation matches a filename (case-insensitive), the logo loads automatically.

---

### 2.7 Score vs Time Display

**Code (lines 179–181):**

```dart
timeOrScore: game['is_finished']
    ? "${game['home_score']} : ${game['away_score']}"
    : "${game['game_time'].split('T')[0]} ${game['game_time'].split('T')[1].split('.')[0]}"
```

**Example — finished game:**
```
home_score = 2, away_score = 1  →  "2 : 1"
```

**Example — upcoming game:**
```
game_time = "2025-08-18T18:30:00.000Z"
  .split('T')[0]              →  "2025-08-18"
  .split('T')[1].split('.')[0] →  "18:30:00"
Result: "2025-08-18 18:30:00"
```

---

### 2.8 Game Status Logic

| Condition | Status shown |
|---|---|
| `game['is_finished'] == true` | `"FT"` |
| More than 125 min since kickoff | `"FT"` |
| Between kickoff and kickoff + 125 min | `"Live"` |
| Before kickoff | `"NS"` |

The app adds **UTC+3** manually to `DateTime.now()` (line 150–152) to align with the server's timezone:

```dart
DateTime now = DateTime.now().toUtc().add(Duration(hours: 3));
```

---

### 2.9 Banner Image

Each match card has a background banner image.

```dart
bannerImage:
    game['game_banner'] != null && game['game_banner'].isNotEmpty
    ? NetworkImage(game['game_banner'])         // API banner URL
    : AssetImage("images/pl_logos/pl.jpg")      // default local banner
```

If the API provides a banner URL, it loads from the network. Otherwise the default `pl.jpg` image is used as background.

---

### 2.10 Prediction Lock

When the user taps a match card to make a prediction:

```dart
bool isLocked = gameTime.difference(now).inMinutes <= 60;

if (isLocked) {
    Service.showMessage("Prediction closed, less than 1 hour left...");
    return;  // block navigation
}

// else → navigate to PredictScreen
```

The window closes **1 hour before kickoff**. After that the Predict button does nothing except show a toast.

---

### 2.11 Empty State

If `games == null` or `games.length == 0`:

```
[soccer ball icon]
"No upcoming matches right now."
"Check back later for more action!"
```

---

### 2.12 Refresh Button

A `FloatingActionButton` in the bottom-right corner (lines 104–115):

```dart
FloatingActionButton(
  backgroundColor: kSecondaryColor,
  onPressed: () {
    _getPredictions();
    _getGames();
  },
  child: Icon(Icons.refresh),
)
```

Tapping it re-runs both API calls and re-renders the list.

---

## 3. `team_container_widget.dart` — Full Breakdown

### 3.1 What It Is

A small `StatelessWidget` that renders one team — a square logo box on top and the team abbreviation as a label below. It has no state, no API calls, and no logic beyond building the image path.

It is **not** used in `available_games.dart`. It is used in `predict_screen.dart` to show the two teams side by side when a user is about to submit a prediction.

---

### 3.2 The Automatic Match — Exact Mechanism

```
Input:    teamName = "CHE"   (passed from game['home_team'])
Step 1:   teamName.toString().toLowerCase()  →  "che"
Step 2:   "images/pl_logos/" + "che" + ".png"
Result:   "images/pl_logos/che.png"
Display:  Chelsea badge ✅
```

No map, no lookup table, no hardcoding. The file just needs to exist with the right name.

---

### 3.3 Full Widget Annotated

```dart
class TeamContainer extends StatelessWidget {
  final String teamName;   // e.g. "CHE", "LIV", "ARG"

  Widget build(BuildContext context) {

    return Expanded(
      // Expanded makes both home and away TeamContainers
      // share the row width equally (50% each)

      child: Column(
        children: [

          Container(
            height: getProportionateScreenHeight(kDefaultPadding * 3), // ~45px
            width:  getProportionateScreenWidth(kDefaultPadding * 3),  // ~45px
            decoration: BoxDecoration(

              image: DecorationImage(
                image: AssetImage(
                  "images/pl_logos/${teamName.toString().toLowerCase()}.png"
                  //                 ↑ automatic match
                ),
                fit: BoxFit.fill,
              ),

              shape: BoxShape.rectangle,
              color: kPrimaryColor.withValues(alpha: 0.6),
              // ↑ white background shown if image file is missing
              // prevents a black/transparent hole

              borderRadius: BorderRadius.circular(
                getProportionateScreenHeight(5),  // ~5px rounded corners
              ),
            ),
          ),

          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),

          CustomTag(
            color: Colors.transparent,
            text: teamName.toUpperCase(),
            // "che" → displayed as "CHE"  (but input is already uppercase from API)
          ),

        ],
      ),
    );
  }
}
```

---

### 3.4 Where It Is Used

`TeamContainer` is used in `predict_screen.dart` inside a `Row` to display the two teams facing each other:

```dart
Row(
  children: [
    TeamContainer(teamName: game['home_team']),   // left
    // ... VS / score input in the middle
    TeamContainer(teamName: game['away_team']),   // right
  ],
)
```

---

### 3.5 Limitation

`TeamContainer` only works with **club abbreviations** mapped to `images/pl_logos/`.

| Use case | Works? | Why |
|---|---|---|
| Premier League clubs (CHE, LIV, ARS...) | ✅ | files exist in `pl_logos/` |
| National teams by ISO code (BR, FR, DE) | ✅ if files exist | only a few national team PNGs are in `pl_logos/` |
| Country flags for World Cup nations | ❌ | flags are in `country_code_picker/flags/`, not `pl_logos/` |

To support World Cup national flags, the image path on line 27 would need to change to:

```dart
// current:
"images/pl_logos/${teamName.toLowerCase()}.png"

// for country flags:
"packages/country_code_picker/flags/${isoCode.toLowerCase()}.png"
```

---

## 4. How Both Files Connect

```
WorldCupScreen (prediction_home.dart)
    │
    ├── Tab 1 → AvailableGames (available_games.dart)
    │               │
    │               ├── getGames() → API
    │               ├── getPredictions() → API
    │               │
    │               └── ListView → MatchRow (prediction_card.dart)
    │                               └── shows logos from API or local fallback
    │
    └── Tab 2 → MyPrediction (my_prediction.dart)


User taps a MatchRow card
    └── Navigator.push → PredictScreen (predict_screen.dart)
                              │
                              ├── TeamContainer(game['home_team'])  ← team_container_widget.dart
                              └── TeamContainer(game['away_team'])  ← team_container_widget.dart
```

---

## 5. Data Flow — End to End

```
Server
  │
  └── POST /api/admin/get_game_user_history
            │
            └── games list (home_team, away_team, logos, game_time, scores...)
                      │
                      └── AvailableGames state (games variable)
                                │
                                └── ListView.builder
                                          │
                                          ├── filter: skip predicted + unfinished
                                          │
                                          └── MatchRow card
                                                │
                                                ├── logo: API URL → local fallback
                                                ├── status: FT / Live / NS
                                                ├── timeOrScore: score or datetime
                                                └── onTap → PredictScreen
                                                                │
                                                                └── TeamContainer
                                                                      │
                                                                      └── logo: images/pl_logos/{name}.png
```

---

## 6. Key Gotchas

| # | Gotcha | Detail |
|---|---|---|
| 1 | `games` is untyped (`var`) | It's a raw `dynamic` from JSON decode. No model class. Accessing a wrong key won't crash until runtime. |
| 2 | Timezone is hardcoded to UTC+3 | Line 150–152 adds 3 hours to UTC manually. If the server changes timezone this breaks silently. |
| 3 | 125-minute live window is hardcoded | No overtime or extra time awareness. A match going to penalties will show "FT" after 125 min even if still playing. |
| 4 | Prediction lock is client-side only | The 1-hour lock at line 203 is only in the app. The server should also validate this on the `predict_game` endpoint. |
| 5 | `TeamContainer` has no error fallback | If `images/pl_logos/xyz.png` doesn't exist, Flutter throws an asset error in debug. In release it shows a white box silently. |
| 6 | `countries` map in `world_cup.dart` is dead code | It is defined but imported and used nowhere in the app. |
| 7 | `SizedBox.shrink()` hides predicted games | Predicted + unfinished games are hidden, not removed. They still occupy a zero-size slot in the list. |
