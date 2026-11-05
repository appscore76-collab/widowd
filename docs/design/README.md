# Widowd design reference

This folder is the design source of truth for the Flutter app (iPhone, Android and web).
It was exported from the Widowd design canvas on claude.ai.

```
docs/design/
├── README.md        ← this file
├── tokens.json      ← colours, fonts, sizes, radii, breakpoints
├── mobile/          ← 24 iPhone screens (390 × 844)
└── web/             ← 7 desktop layouts (1440 wide, responsive)
```

## How to read the screen files

Each `*.dc.html` file is one screen. They are design files, not app code, and won't run on
their own (they expect the design tool's `support.js`). Read them as a precise spec:

- **The markup and inline `style="…"` are exact:** sizes, colours, spacing, radii, copy.
- **`{{name}}` placeholders** are filled by the `<script>` block at the bottom of each file.
  That script shows the screen's states (for example: liked / not liked, selected plan,
  blurred / unblurred photos) and the sample data.
- **`<sc-for>`** = a repeated list; **`<sc-if>`** = shown only in one state.
- **`href="Other.dc.html"`** links show the navigation between screens.

Build each screen in Flutter to match. Don't copy the HTML.

## One codebase, three widths

The app is one Flutter codebase. Each page is built once and responds to the window width:

| Width | Layout | Source |
|---|---|---|
| 0–599px (phones, small browser windows) | iPhone layout with bottom tab bar | `mobile/` |
| 600–1023px (tablets, narrow windows) | Sidebar becomes a top bar; one column | `web/` collapsed |
| 1024px and up (desktop) | Left sidebar (248px), content max 1200px | `web/` |

## Screen map

| Feature | Phone | Desktop (1024px+) |
|---|---|---|
| Daily suggestions | `mobile/Discover` | `web/WebDiscover` (card grid) |
| Likes you (free) | `mobile/LikesYou` (heart button in Discover) | `web/WebLikes` (sidebar item) |
| Search | `mobile/Search` | `web/WebSearch` (filters panel + results grid) |
| Profile | `mobile/Profile` | `web/WebProfile` (gallery left, details right) |
| Chats | `mobile/Matches` + `mobile/Chat` | `web/WebChats` (list and conversation side by side) |
| Blocked chat | `mobile/ChatBlocked` | Same pattern inside `WebChats` |
| Community | `mobile/Community` + `mobile/Thread` | `web/WebCommunity` (topics · thread · guidelines) |
| New community post | `mobile/NewPost` | Use the mobile layout in a centred card, max 640px |
| Plans | `mobile/Premium` | `web/WebPremium` (card payment on web) |
| Sign-up: Welcome, Intent, About, Photos | `mobile/Main`, `Intent`, `About`, `Photos` | Use the mobile layout in a centred card, max 480px |
| Plan a date, Pick place, Date invite | `mobile/PlanDate`, `PickPlace`, `DateInvite` | Centred panel or dialog, max 560px |
| Video call | `mobile/Video` | Full window |
| Verification, ID check, Incognito | `mobile/Verify`, `IdCheck`, `Incognito` | Centred card, max 560px |

Screens without a desktop design: centre the mobile layout in a card on the `background`
colour, inside the desktop sidebar shell.

## Web-only differences

These are deliberate. Don't build these on web:

- **Private view-once photos (`SharePhoto`):** mobile only. Browsers can't block screenshots.
  On web, the chat's photo button is disabled with the note shown in `WebChats`.
- **Share my date (`ShareDate`):** live location sharing is mobile only. Browsers can't share
  location in the background. Web can show the date details but not start live sharing.
- **Payments:** in-app purchase (RevenueCat) on iPhone and Android. On web, card payment
  (decision pending: RevenueCat Web Billing / Stripe). Phone subscriptions also unlock Plus on web.
- **Notifications:** web push on desktop browsers, with email as the fallback.

## Rules that apply everywhere

- Font: Plus Jakarta Sans. Colours and sizes from `tokens.json` only.
- Touch targets at least 44px. Text contrast at least 4.5:1.
- Photos stay blurred until two people match. Then they unlock for those two only.
- Free members can send likes and see who likes them (photos blurred).
- Liking back (making a match) needs Plus, unless the person who liked you has Plus.
- A match with at least one Plus member is fully open to both: photos, messages, video calls, dates.
- Never reveal another member's subscription status, except the "Free to like back" tag on a like that came with Plus.
- Never show private message text in notifications.

## Using this with Claude Code

Example prompt:

> "Build the Discover page following `docs/design/mobile/Discover.dc.html` for phone widths
> and `docs/design/web/WebDiscover.dc.html` for 1024px and up, using the breakpoints and
> colours in `docs/design/tokens.json`. Put shared colours and text styles in
> `lib/theme/widowd_theme.dart`."
