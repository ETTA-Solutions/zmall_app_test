# Predict and Win — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is "Predict and Win"?

"Predict and Win" (internally called **World Cup** / prediction feature) lets users  
**predict the scores of upcoming sports matches** and win prizes based on accuracy.

Users see upcoming games, submit their predicted score (e.g., 2-1), and later  
see if their prediction was correct. This is separate from the borsa (wallet) system,  
though both live under the same home section.

**Note:** Despite the folder name `world_cup/`, this feature works for any sport game  
loaded by the backend — not just football/soccer World Cup.

---

## Where Predict and Win Lives in the Codebase

```
lib/
├── world_cup/
│   ├── prediction_home.dart            ← Tab container (Available Games + My Predictions)
│   ├── available_games.dart            ← Game list + predictions fetch
│   ├── predict_screen.dart             ← Submit a score prediction for a game
│   ├── my_prediction.dart              ← View user's submitted predictions
│   └── components/
│       ├── prediction_card.dart        ← Game card UI
│       ├── team_container_widget.dart  ← Team logo + name widget
│       ├── score_prediction_widget.dart← Score input widget
│       ├── logo_container.dart         ← Logo display
│       └── win_percentage_widget.dart  ← Win probability display
└── borsa/
    └── borsa_screen.dart               ← Wallet screen (separate but related)
```

**Borsa route:** `/borsa`  
Predict and Win is accessed from home (no separate named route — uses `MaterialPageRoute`).

---

## User Journey (Screen by Screen)

```
[Home Screen]
     │  tap "Predict and Win" / games section
     ▼
[PredictionHome]  (2 tabs)
     │
     ├── Tab 1: Available Games
     │     API: POST /api/admin/get_game_user_history  → load all games
     │     API: POST /api/admin/get_prediction_history → load user's existing predictions
     │     Shows games as cards (home team vs away team)
     │     Badges: NS (Not Started), Live, FT (Full Time)
     │     Tap a game card
     │
     └── Tab 2: My Predictions
           Shows all predictions the user has submitted
     ▼
[PredictScreen]  (pushed from Available Games)
     │  • Shows: home team logo, away team logo, game time, stadium
     │  • API: POST /api/admin/get_prediction_history → check if already predicted
     │  • User picks: Home Win / Draw / Away Win
     │  • User optionally enters exact score (home_score, away_score)
     │  • "Submit" button
     │  • API: POST /api/admin/predict_game  → save prediction
     ▼
[Back to PredictionHome]  (My Predictions tab updates)
```

---

## All API Calls — Predict and Win

### 1. Get Games List
**When:** Available Games tab loads  
**File:** `lib/world_cup/available_games.dart:272`

```
POST {baseUrl}/api/admin/get_game_user_history
Content-Type: application/json

REQUEST BODY:
{}    ← empty, no parameters required

RESPONSE (success):
{
  "success": true,
  "games": [
    {
      "_id":              "string",     // game ID
      "home_team":        "string",     // home team name
      "away_team":        "string",     // away team name
      "home_score":       number,       // final score (if finished)
      "away_score":       number,       // final score (if finished)
      "game_time":        "string",     // ISO datetime of the match
      "is_finished":      boolean,      // true = match completed
      "stadium":          "string",     // venue name
      "type":             "string",     // tournament/league type
      "game_banner":      "string",     // banner image URL
      "home_team_logo":   "string",     // home team logo URL
      "away_team_logo":   "string"      // away team logo URL
    }
  ]
}
```

---

### 2. Get User's Predictions
**When:** Available Games tab loads (to show which games are already predicted)  
**Also when:** PredictScreen loads (to check if user already submitted for this game)  
**Files:**  
- `lib/world_cup/available_games.dart:325`  
- `lib/world_cup/predict_screen.dart:661`

```
POST {baseUrl}/api/admin/get_prediction_history
Content-Type: application/json

REQUEST BODY:
{
  "start_date":    "",                  // empty = no date filter
  "end_date":      "",                  // empty = no date filter
  "search_field":  "user_detail._id",   // filter by user
  "search_value":  "string"             // user._id
}

RESPONSE (success):
{
  "success": true,
  "scores": [
    {
      "game_id":     "string",    // links to game._id
      "home_win":    boolean,     // user predicted home team wins
      "away_win":    boolean,     // user predicted away team wins
      "draw":        boolean,     // user predicted draw
      "home_score":  number,      // user's predicted home score
      "away_score":  number       // user's predicted away score
    }
  ]
}
```

---

### 3. Submit Prediction
**When:** User taps "Submit" on PredictScreen  
**File:** `lib/world_cup/predict_screen.dart:715`

```
POST {baseUrl}/api/admin/predict_game
Content-Type: application/json

REQUEST BODY:
{
  "user_id":       "string",   // user._id
  "server_token":  "string",   // user.server_token
  "game_id":       "string",   // game._id (which game is being predicted)
  "home_score":    number,     // predicted home team score (integer)
  "away_score":    number,     // predicted away team score (integer)
  "home_win":      boolean,    // true if user picks home team wins
  "away_win":      boolean,    // true if user picks away team wins
  "draw":          boolean,    // true if user picks draw
  "penalties":     false,      // always false (not used currently)
  "penalty_score": 0           // always 0 (not used currently)
}

RESPONSE (success):
{
  "success": true
}

RESPONSE (error):
{
  "success": false,
  "error_code": number   // e.g. 999 = session expired
}
```

---

## Prediction Logic Rules

One and only one of these must be `true` when submitting:
- `home_win: true, away_win: false, draw: false` → user picks home team wins
- `away_win: true, home_win: false, draw: false` → user picks away team wins
- `draw: true, home_win: false, away_win: false` → user picks draw

`home_score` and `away_score` are the predicted exact scoreline (e.g., 2-1).

---

## Game Status Indicators

| Status | Meaning | How Shown |
|--------|---------|-----------|
| `is_finished: false` + future `game_time` | Not started | Badge: `NS` |
| `is_finished: false` + past `game_time` | In progress | Badge: `Live` |
| `is_finished: true` | Match finished | Badge: `FT` with actual scores |

---

## Related: Borsa (Wallet)

The `borsa/` folder is a **wallet/top-up screen** — separate from Predict and Win  
but both appear in the same home section.

**Route:** `/borsa`  
**Purpose:** Users can top-up their zmall wallet balance using Telebirr/USSD  
**Files:**
- `lib/borsa/borsa_screen.dart` — main wallet screen
- `lib/borsa/topup_kifiya/ussd_topup_payment.dart` — USSD top-up flow
- `lib/borsa/topup_kifiya/inapp_topup_payment.dart` — in-app top-up flow
- `lib/borsa/refund/refund_service.dart` — refund handling

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| Game list + predictions | `lib/world_cup/available_games.dart` |
| Submit prediction screen | `lib/world_cup/predict_screen.dart` |
| My predictions view | `lib/world_cup/my_prediction.dart` |
| Tab container | `lib/world_cup/prediction_home.dart` |
| Game card UI | `lib/world_cup/components/prediction_card.dart` |
| Score input widget | `lib/world_cup/components/score_prediction_widget.dart` |
| Borsa wallet screen | `lib/borsa/borsa_screen.dart` |
