# World Cup Feature — Simple Guide

---

## What does this feature do?

It lets users **watch upcoming matches** and **predict the score** to win prizes.

---

## The Screens

```
World Cup Screen
├── Tab 1 → Available Games   (available_games.dart)
└── Tab 2 → My Predictions    (my_prediction.dart)
```

When you tap a match → opens Predict Screen
- Predict Screen uses **TeamContainer** to show the two teams

---

## available_games.dart — Simply

### What it does
1. Opens → calls the API to get all matches
2. Shows each match as a card
3. If you already predicted a match → hides that card
4. You tap a card → go predict the score

---

### The API it calls

**Get all matches:**
```
POST /api/admin/get_game_user_history
```
Returns a list of games with team names, logos, time, stadium, scores.

**Get your predictions:**
```
POST /api/admin/get_prediction_history
```
Returns the list of games you already predicted.

---

### How the match card works

```
Is the game already predicted by me AND not finished?
    YES → hide the card (don't show it)
    NO  → show the card
```

```
What time is it now vs kick-off time?
    Before kick-off              → show "NS" (Not Started)
    After kick-off, within 125min → show "Live"
    After 125min OR api says done → show "FT" (Full Time)
```

```
Is the game finished?
    YES → show score  "2 : 1"
    NO  → show date & time  "2025-08-18 18:30:00"
```

---

### How the team logo loads

```
Step 1 → Does the API give a logo URL?
            YES → load from internet

Step 2 → No URL from API?
            → build path from team name automatically
            → "CHE" becomes "images/pl_logos/che.png"

Step 3 → Internet image fails?
            → fall back to same local file
```

No manual list needed. The logo finds itself from the team name.

---

### Prediction lock

```
Less than 1 hour before kick-off?
    → "Prediction closed" message
    → can't open predict screen
```

---

### Refresh button

Bottom-right corner button → re-calls both APIs → updates the list.

---

## team_container_widget.dart — Simply

### What it does

Shows **one team** — logo box on top, name label below.
Used inside the Predict Screen to show home team (left) and away team (right).

---

### How the logo loads

```
teamName = "CHE"
    → lowercase → "che"
    → "images/pl_logos/che.png"
    → Chelsea logo appears ✅
```

That's it. The name from the API becomes the file name automatically.

---

### What it looks like

```
┌─────────┐
│  [logo] │   ← 45x45px image from images/pl_logos/
└─────────┘
   [ CHE ]    ← team name in uppercase
```

---

## How everything connects

```
API
 └── games list
       └── Available Games screen
             └── match cards
                   └── user taps card
                         └── Predict Screen
                               ├── TeamContainer (home team)
                               └── TeamContainer (away team)
```

---

## Key things to remember

| Thing | Simple explanation |
|---|---|
| Logo matching | Team name → lowercase → find the PNG file automatically |
| Hide predicted games | If you already predicted + game not done → card disappears |
| Live detection | Between kick-off and kick-off + 125 minutes = Live |
| Prediction lock | Closes 1 hour before kick-off |
| Country flags | NOT used here — only club logos from `images/pl_logos/` |
| `countries` map | Defined in `world_cup.dart` but **never used** anywhere |
