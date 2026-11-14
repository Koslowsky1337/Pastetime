# Changelog

## 1.0.0-beta2

Please report anything odd: https://github.com/Koslowsky1337/Pastime/issues

- Horde and Alliance: the window wears your faction's colours. Alliance characters get Gryphon Flight, Ram Dash and Bell Echo instead of Wind Rider, Kodo Dash and Totem Echo, Elwynn fish in Fishing and a meadow for the Wind Serpent.
- Fixed: on the game-over screen, the keyboard stayed locked when a fight started and "Hide in combat" was switched off.
- The version in the addon list and in `/pastime diag` now names the exact build.
- Zeppelins and boats: the window no longer reopens every ten minutes while you stand at a dock; a `/reload` during the ride no longer starts a phantom trip on arrival; falling off after departure, a hearthstone or dying no longer leaves wrong travel times or routes behind.
- Route records: a route can be deleted (the button asks once more before it does).
- English clients show 1,054,000 and ISO dates instead of the German 1.054.000 and 13.11.26.
- German client: Undercity, Thunder Bluff, Stormwind, Booty Bay, Ratchet and Southshore are named as the game names them. The Alliance test flight heads for Stormwind.

## 1.0.0-beta1 – first beta

All 19 games have been reviewed. Please report anything odd on GitHub.

**All games**
- Real-time games (Wind Serpent, Wind Rider, Kodo Dash, Kobold Bash, Rockfall, Wallbreaker, Murloc Invasion) show a 3-2-1 countdown when you resume after a pause, a landing or a fight.
- Score popups and messages are no longer hidden under the game board.
- The sidebar always shows how to pause.
- Your faction matters: Four in a Row, minefield flags, card and rune backs show Horde or Alliance.

**Games**
- Kodo Dash: new rock overhangs to slide under; the score is now shown as metres.
- Goblin Blackjack: your gold carries over between games and bets grow with it; going broke scores the highest gold of the run.
- Solitaire: drag cards with the mouse, a click sends a fitting card to its suit pile, fixed piles for each suit.
- Rockfall: a short lock delay lets you slide a landed block.
- Rune Pairs: clicking a third card covers a wrong pair at once.
- Smaller fixes for Fishing, Tavern Dice, Totem Echo, Wallbreaker and Word Guess.

## 1.0.0-alpha1 – test build

First automatic CurseForge build, mainly to test the packaging. The games are still being reviewed one by one.

- Wind Serpent: speeds up every 8 eggs instead of every egg; the sidebar shows the level. Fixed a gap in the body when the head follows the tail closely.
- Wind Serpent and Wind Rider: 3-2-1 countdown after a pause, so you don't crash right away.
- After game over, Space restarts only after 1.5 seconds (the button works at once).
- Game details and route records: the parchment now fills the whole panel; the route line uses the full width.

## Feature overview (first import, before alpha1)

- 19 mini-games in three categories: Arcade, Puzzles, Dice & Cards.
- Opens by itself on flight paths, zeppelins and boats; landing alarm with *Keep playing* or *Finish & score*.
- Leaderboards per game and difficulty, plus a top 5 for every route you travel. Abandoned rounds never count.
- English and German texts, including an English word list for Word Guess and the right keys for Goblin Blackjack in each language.
- Settings under *Options → AddOns → Pastime*, entry in the minimap addon compartment, right-click on the minimap button opens the settings.
- `/pastime` with English commands; the German commands keep working.
- Groundwork for playing together in a later update (not active yet; nothing is sent to other players).
