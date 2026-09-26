# Ember TV for Roku

The Ember TV Roku channel, written in BrightScript / SceneGraph, with its logos, splash screens and fonts.

## How it works

- **Sign-in:** the channel shows a short code and a QR code. The viewer approves it at
  app.emberstreaming.com/activate on a phone or computer, and the Roku signs in on its own
  (`ActivationScene`, `ActivationTask`). "Sign in with email instead" opens an email and
  password form (`LoginScene`) for the same account.
- **Server:** everything talks to the Ember TV API v2 at `https://app.emberstreaming.com/v2`
  (`source/emberApi.brs`). The session (access + refresh token) is kept in the registry and
  refreshed before it expires.
- **My Rentals** (`RentalsScene`) lists active and recently ended rentals with the time left.
- **Playback** (`PlayerScene`) asks for a fresh signed stream on every play, then saves the
  position every 30 seconds, on pause and on Back. "Resume" continues from the position
  saved on any device (web, Apple TV, Fire TV, Roku).
- **Deep links:** `contentId` is a film's id or slug (`mediaType` `movie`). If the film is
  in the signed-in account's library and still watchable, it plays; a signed-out viewer
  signs in first, then it plays.

## Test on a Roku

1. Turn on developer mode on the Roku (Home ×3, Up ×2, Right, Left, Right, Left, Right).
2. Zip the **contents** of this folder (`manifest`, `source/`, `components/`, `images/`,
   `fonts/` at the top level of the zip, not inside another folder).
3. Open `http://<roku-ip>` in a browser, sign in with the developer password, and upload
   the zip.

## Roku certification

`certification/Login.rasp` and `certification/Logout.rasp` are the automated test scripts
for Roku's review. `script-login` and `script-password` are placeholders Roku fills in with
the test account entered in the developer dashboard.

- **Login:** launches with a deep link to *The Apocalypse of St. John*, chooses
  "Sign in with email instead", types the email and password, signs in, and the deep-linked
  film plays (the test account must have an active rental of it).
- **Logout:** launches signed in with the same deep link (the film plays), presses Back to
  My Rentals, then Up to Refresh, Right to Sign Out, OK.

Deep links play straight away (from the resume point if there is one), with no Resume /
Start Over prompt, as Roku requires.
