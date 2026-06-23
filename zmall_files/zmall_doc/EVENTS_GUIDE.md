# Events Feature — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is Events?

Events is a feature that lets users **browse and buy tickets for local events** (concerts, festivals, sports, etc.) directly inside the zmall app.  
It is a completely separate section — it does NOT use the regular cart/order/delivery flow.  
Payment for tickets is handled via **Telebirr** through an external `ticket_url` link.

---

## Where Events Lives in the Codebase

```
lib/
├── events/
│   ├── events_screen.dart                  ← Main events listing (vertical swipe)
│   └── components/
│       ├── ticket_order_payment.dart       ← Ticket invoice generation screen
│       └── description_row.dart            ← UI row widget for event details
└── kifiya/
    └── components/
        └── event_santim.dart               ← WebView for Telebirr payment
```

**Route:** `/events`

---

## User Journey (Screen by Screen)

```
[Home Screen]
     │  tap "Events" card / banner
     ▼
[EventsScreen]  /events
     │  • API: POST /api/admin/get_user_event_history  → load all events
     │  • Events shown as a VERTICAL SWIPE PageView (one event per page)
     │  • Each event shows: banner image, name, date, address, tags, description
     │  • Tap "Get Ticket" button
     ▼
[EventSantimPayScreen]  (no named route — MaterialPageRoute)
     │  • Opens a WebView at event's ticket_url
     │  • Payment processed externally via Telebirr
     │  • User completes payment inside the WebView
```

> Note: `TicketOrderPayment` screen (which calls `generate_ticket_invoice`)  
> exists in the codebase but is currently **commented out** in the events flow.  
> The active flow goes directly to the `EventSantimPayScreen` WebView.

---

## All API Calls — Events Feature

### 1. Get Events List
**When:** EventsScreen loads  
**File:** `lib/events/events_screen.dart:803`

```
POST {baseUrl}/api/admin/get_user_event_history
Content-Type: application/json

REQUEST BODY:
{}    ← empty, no parameters required

RESPONSE (success):
{
  "success": true,
  "events": [
    {
      "_id":          "string",         // event ID
      "name":         "string",         // event title
      "description":  "string",         // full description
      "address":      "string",         // venue address
      "start_date":   "string",         // ISO date
      "end_date":     "string",         // ISO date
      "event_tags":   "string",         // comma-separated tags e.g. "music,live,festival"
      "is_featured":  boolean,
      "image_url":    ["string", ...],  // array of image paths (relative to baseUrl)
      "ticket_url":   "string",         // external Telebirr payment URL
      "organization_detail": {
        "name": "string"                // organizer name
      },
      "ticket_types": [
        {
          "_id":          "string",
          "ticket_name":  "string",     // e.g. "VIP", "General"
          "ticket_price": number,       // price in ETB
          "description":  "string"
        }
      ]
    }
  ]
}
```

---

### 2. Generate Ticket Invoice (currently unused in active flow)
**When:** If ticket invoice flow is re-enabled  
**File:** `lib/events/components/ticket_order_payment.dart:195`

```
POST {baseUrl}/api/admin/generate_ticket_invoice
Content-Type: application/json

REQUEST BODY:
{
  "user_id":       "string",   // user._id
  "server_token":  "string",   // user.server_token
  "ticket_type_id":"string",   // selected ticket_types._id
  "quantity":      number      // number of tickets
}

RESPONSE (success):
{
  "success": true,
  "ticket_order_payment": {
    "created_at":         "string",   // ISO datetime
    "organization_name":  "string",
    "event_name":         "string",
    "ticket_name":        "string",
    "total":              number,     // total price
    "quantity":           number
  }
}
```

---

## Events Data Model

| Field | Type | Description |
|-------|------|-------------|
| `_id` | string | Unique event ID |
| `name` | string | Event title |
| `description` | string | Full event description |
| `address` | string | Physical venue address |
| `start_date` | string | Start date/time (ISO) |
| `end_date` | string | End date/time (ISO) |
| `event_tags` | string | Comma-separated filter tags |
| `is_featured` | boolean | Show as featured/highlighted |
| `image_url[]` | string[] | Banner images (relative paths, prefix with baseUrl) |
| `ticket_url` | string | External Telebirr payment URL |
| `organization_detail.name` | string | Organizer/host name |
| `ticket_types[]` | array | Available ticket tiers with prices |

---

## UI Behavior Notes

- Events are shown in a **vertical PageView** — user swipes up/down between events
- If an event has 2 images, the second image is shown as alternate/background
- `event_tags` is a string like `"music,live,outdoor"` — the app splits it by comma to build filter chips
- The "Get Ticket" button opens `ticket_url` in a WebView — payment is fully external (Telebirr handles it)
- Timeout per request: **15 seconds**

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| Main events screen | `lib/events/events_screen.dart` |
| Invoice screen (inactive) | `lib/events/components/ticket_order_payment.dart` |
| Detail row widget | `lib/events/components/description_row.dart` |
| WebView payment screen | `lib/kifiya/components/event_santim.dart` |
