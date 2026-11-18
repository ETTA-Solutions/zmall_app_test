# safe_prod: Disabled Features (Chatbot AI + Subscription)

Branch: `safe_prod`

Both features were turned off by **commenting out their entry points**.
Every commented block is marked with `// safe_prod: ...` so you can find them:

```
grep -rn "safe_prod" lib
```

Nothing was deleted. The feature code (`lib/help/support_chat/`, `lib/profile/subscription/`,
`getSubscriptionDetail` in `core_services.dart`) is untouched, just unreachable.

---

## 1. Chatbot AI

### `lib/home/home_screen.dart`
- Imports commented out:
  - `help/support_chat/components/floating_chat_button.dart`
  - `help/support_chat/support_chat_screen.dart`
- `floatingActionButton: FloatingChatButton(...)` and `floatingActionButtonLocation` commented out in `build()`.

### `lib/utils/routes.dart`
- Import `help/support_chat/support_chat_screen.dart` commented out.
- Route `SupportChatScreen.routeName: (context) => SupportChatScreen(),` commented out.

## 2. Subscription (Zmall Pro)

### `lib/profile/components/body.dart`
- Import `profile/subscription/subscription.dart` commented out.
- The "Zmall Pro" `NewProfileListTile` (+ the `Divider` after it) commented out.

### `lib/utils/routes.dart`
- Import `profile/subscription/subscription.dart` commented out.
- Route `SubscriptionScreen.routeName: (context) {...}` commented out.

---

## How to re-enable (undo)

For each file above, remove the `// ` prefix from the lines under the `// safe_prod:` markers
(and delete the marker comment). Specifically:

1. `lib/home/home_screen.dart` – uncomment the 2 imports and the `floatingActionButton` + `floatingActionButtonLocation` lines.
2. `lib/profile/components/body.dart` – uncomment the import and the "Zmall Pro" tile + `Divider`.
3. `lib/utils/routes.dart` – uncomment the 2 imports and the 2 routes (`SubscriptionScreen`, `SupportChatScreen`).

Then run `flutter analyze` to confirm no errors.

### Alternative: undo with git
If these edits are committed on `safe_prod` as their own commit, you can revert them:

```
git revert <commit-sha>
```

Or take the files back from the branch you came from (`odoo_place_order`):

```
git checkout odoo_place_order -- lib/home/home_screen.dart lib/profile/components/body.dart lib/utils/routes.dart
```

(Only do this if you have no other wanted changes in those three files on `safe_prod`.)

## Not touched
- MCP AI-cart push handling (`ai_cart` in `lib/main.dart`, `lib/mcp/`) – separate feature, still active.
