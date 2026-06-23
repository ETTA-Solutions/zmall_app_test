# Where Does `game['home_team_logo']` Come From?

> This guide traces every `game[...]` field from the server all the way to the match card on screen.

---

## The Journey — 4 Steps

```
STEP 1       STEP 2          STEP 3         STEP 4
Server  →  getGames()  →  _getGames()  →  MatchRow card
(API)      (HTTP call)    (saves data)    (shows data)
```

---

## Step 1 — The Server sends JSON

The server is at this address:
```
POST https://testapp.zmall.et/api/admin/get_game_user_history
```

The server replies with a JSON object like this:

```json
{
  "success": true,
  "games": [
    {
      "_id":             "64f2abc...",
      "type":            "Game Week 1",
      "home_team":       "CHE",
      "away_team":       "LIV",
      "home_team_logo":  "https://cdn.example.com/che.png",
      "away_team_logo":  "https://cdn.example.com/liv.png",
      "game_time":       "2025-08-18T18:30:00.000Z",
      "stadium":         "Stamford Bridge",
      "is_finished":     false,
      "home_score":      0,
      "away_score":      0,
      "game_banner":     "https://cdn.example.com/banner.jpg"
    }
  ]
}
```

Every `game['...']` you see in the code comes directly from one of these fields.

---

## Step 2 — `getGames()` makes the HTTP call

**Location:** `available_games.dart` line 272

```dart
Future<dynamic> getGames() async {
    var url = "${baseUrl}/api/admin/get_game_user_history";

    http.Response response = await http.post(
        Uri.parse(url),
        headers: { "Content-Type": "application/json" },
        body: "{}",          // sends empty body — no filter, get all games
    );

    return json.decode(response.body);  // ← turns raw JSON text into a Dart Map
}
```

`json.decode()` converts the server's text reply into a Dart object the app can read.

```
Server sends text:   '{"success":true,"games":[...]}'
json.decode turns it into:  { "success": true, "games": [...] }
```

---

## Step 3 — `_getGames()` saves the data into state

**Location:** `available_games.dart` line 53

```dart
void _getGames() async {
    var data = await getGames();        // data = the full JSON from server

    if (data != null && data['success']) {
        setState(() {
            games = data['games'];      // ← saves ONLY the games list
        });
    }
}
```

After this line runs:
```
games = [
    { "_id": "64f2abc...", "home_team": "CHE", "home_team_logo": "https://...", ... },
    { "_id": "64f2abd...", "home_team": "TOT", "home_team_logo": null, ... },
    ...
]
```

`games` is now a list. Each item in the list is one game object.

---

## Step 4 — `ListView.builder` picks each game one by one

**Location:** `available_games.dart` line 128

```dart
ListView.builder(
    itemCount: games.length,
    itemBuilder: (context, index) {

        final game = games[index];   // ← picks ONE game from the list

        // game is now:
        // { "home_team": "CHE", "home_team_logo": "https://...", ... }

        return MatchRow(
            homeClubName: game['home_team'],         // "CHE"
            homeClubLogo: game['home_team_logo'],    // "https://cdn.example.com/che.png"
            ...
        );
    }
)
```

`games[index]` picks the game at position 0, then 1, then 2... for each card in the list.

---

## Where Every `game['...']` Field Comes From

| Code | API field | Example value |
|---|---|---|
| `game['home_team']` | `home_team` | `"CHE"` |
| `game['away_team']` | `away_team` | `"LIV"` |
| `game['home_team_logo']` | `home_team_logo` | `"https://cdn.../che.png"` or `null` |
| `game['away_team_logo']` | `away_team_logo` | `"https://cdn.../liv.png"` or `null` |
| `game['game_time']` | `game_time` | `"2025-08-18T18:30:00.000Z"` |
| `game['stadium']` | `stadium` | `"Stamford Bridge"` |
| `game['type']` | `type` | `"Game Week 1"` |
| `game['is_finished']` | `is_finished` | `true` or `false` |
| `game['home_score']` | `home_score` | `2` |
| `game['away_score']` | `away_score` | `1` |
| `game['game_banner']` | `game_banner` | `"https://cdn.../banner.jpg"` or `null` |
| `game['_id']` | `_id` | `"64f2abc..."` (MongoDB ID) |

---

## Focus: `game['home_team_logo']` specifically

```dart
homeClubLogo:
    game['home_team_logo']
    ??
    "images/pl_logos/${game['home_team'].toLowerCase()}.png",
```

**Two possible situations:**

### Situation A — Server gives a logo URL

```
Server sends:   "home_team_logo": "https://cdn.example.com/che.png"
game['home_team_logo'] = "https://cdn.example.com/che.png"   ← not null
?? is ignored
Result: app loads logo from the internet URL
```

### Situation B — Server gives null (no logo stored)

```
Server sends:   "home_team_logo": null
game['home_team_logo'] = null   ← null triggers ??
?? kicks in → builds path from team name:
    game['home_team'] = "CHE"
    .toLowerCase()   = "che"
    result           = "images/pl_logos/che.png"
Result: app loads logo from local file in the app
```

---

## Full Data Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│                      SERVER                         │
│  POST /api/admin/get_game_user_history              │
│                                                     │
│  Responds with:                                     │
│  {                                                  │
│    "success": true,                                 │
│    "games": [                                       │
│      {                                              │
│        "home_team": "CHE",          ─────────────────────┐
│        "home_team_logo": "https://...", ─────────────────┤
│        "away_team": "LIV",          ─────────────────────┤
│        "away_team_logo": null,      ─────────────────────┤
│        "game_time": "2025-08-18T18:30:00.000Z", ────────┤
│        "is_finished": false,        ─────────────────────┤
│        "home_score": 0,             ─────────────────────┤
│        "away_score": 0,             ─────────────────────┤
│        "stadium": "Stamford Bridge",─────────────────────┤
│        "game_banner": "https://...",─────────────────────┤
│      }                                               │   │
│    ]                                                 │   │
│  }                                                   │   │
└─────────────────────────────────────────────────────┘   │
                      │                                    │
                json.decode()                              │
                      │                                    │
              getGames() returns data                      │
                      │                                    │
              _getGames() saves:                           │
              games = data['games']                        │
                      │                                    │
              ListView.builder loops                       │
              final game = games[index]                    │
                      │                                    │
                      ▼                                    │
┌─────────────────────────────────────────────────────┐   │
│                   MatchRow(...)                      │◄──┘
│                                                     │
│  homeClubName:  game['home_team']      → "CHE"      │
│  homeClubLogo:  game['home_team_logo'] → URL or     │
│                 ?? "images/pl_logos/che.png"        │
│  awayClubName:  game['away_team']      → "LIV"      │
│  awayClubLogo:  game['away_team_logo'] → null       │
│                 ?? "images/pl_logos/liv.png"        │
│  status:        calculated → "NS" / "Live" / "FT"  │
│  timeOrScore:   calculated → "18:30:00" or "2:1"   │
│  stadium:       game['stadium']  → "Stamford Bridge"│
│  isFinished:    game['is_finished'] → false         │
│  bannerImage:   game['game_banner'] → URL or pl.jpg │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
             Match card shown on screen
```

---

## Simple Summary

```
1. App asks server  →  "give me all games"
2. Server replies   →  JSON with game details
3. json.decode      →  turns text into Dart map
4. data['games']    →  saved into games variable
5. games[index]     →  one game picked per card
6. game['field']    →  one piece of data from that game
7. MatchRow(...)    →  card built and shown on screen
```

Everything inside `game['...']` is a field that came directly from the server's JSON response.
