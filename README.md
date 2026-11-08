# Pastime – In-Flight Entertainment

**Long flight path? Waiting for the zeppelin? Pastime gives you something to do.**

Pastime is a collection of 19 small games in a classic-style window. It notices when you start a journey and opens by itself: at the flight master, at a zeppelin tower or on a boat dock. When you arrive, it pauses your game and asks whether you want to keep playing or finish and score the round. Every route has its own leaderboard, so *Orgrimmar → Undercity* gets a podium of its own.

## Features

- **Opens on its own when you travel:** flight paths, zeppelins and boats. You can switch this off and open the window with `/pastime`, the minimap button or a key binding instead.
- **Knows your trip:** after the first time on a route, Pastime remembers how long it takes and shows the time left. When little time is left, long games are greyed out in the list.
- **Landing alarm:** when you land or arrive, the game pauses and you get a soft sound and a large notice. Then choose **Keep playing** or **Finish & score**.
- **Leaderboards:** a top 10 for every game (and every difficulty) plus a top 5 per game for each route you have travelled. Only finished rounds count; quitting early never counts.
- **Short or long:** each game is marked for short flights (1–2 minutes) or long journeys (several minutes).
- **Plays like a real game:** while you play, the keyboard belongs to the game, so you can't walk off a dock by accident. Chat, screenshots and volume keys still work. Pause frees your keys, and combat pauses the game instantly (the window can also hide itself).
- **Classic look and quiet sounds:** parchment, dialog frames and tabs in the style of the original interface. Game sounds play softly on the sound-effects channel.
- **English and German** client support.
- **Lightweight and private:** no libraries needed, nothing is sent to other players or anywhere else. Your scores are stored in your own SavedVariables.

## The games

**Arcade**
- **Wind Serpent** (short): steer a snake through the Barrens and eat murloc eggs.
- **Wind Rider** (short): one-button flying through the spires of Thousand Needles.
- **Kodo Dash** (short): endless runner – jump cacti and rocks, duck under vultures.
- **Kobold Bash** (short): bonk kobolds out of mine shafts, but leave the dynamite alone.
- **Fishing** (short): cast ten times and strike the moment the bobber dips.
- **Rockfall** (long): falling blocks in item-quality colours.
- **Wallbreaker** (long): paddle and ball against a wall of bricks.
- **Murloc Invasion** (long): hold the shore against waves of marching murlocs.

**Puzzles**
- **Goblin Minefield** (short): uncover the safe squares; easy 9×9 or medium 16×16.
- **Totem Echo** (short): repeat the growing sequence of the four elemental totems.
- **Rune Pairs** (short): turn over cards and find matching pairs in as few moves as possible.
- **Gem Code** (short): crack a jeweller's four-gem code in ten tries.
- **Word Guess** (short): guess the five-letter word in six tries; English or German word list.
- **Four in a Row** (short): Horde against an Alliance computer opponent on three difficulty levels.
- **2048** (long): merge tiles from Poor all the way up to Titanic.
- **Gems** (long): swap gems to make rows of three and set off chain reactions; 30 moves.

**Dice & Cards**
- **Goblin Blackjack** (short): ten hands against a goblin dealer, starting with 100 goblin gold.
- **Tavern Dice** (long): roll five dice up to three times and fill all 13 boxes.
- **Solitaire** (long): classic Klondike patience against the clock.

## Supported journeys

- **Flight paths:** all of them. The route is recognised when you pick your destination at the flight master.
- **Zeppelins (Horde):** Orgrimmar ↔ Undercity, Orgrimmar ↔ Grom'gol, Undercity ↔ Grom'gol, Thunder Bluff ↔ Zephras Isle.
- **Boats (everyone):** Booty Bay ↔ Ratchet, Tanaris ↔ Riverglades, Rut'theran ↔ Auberdine.
- **Boats and zeppelins (Alliance):** Stormwind ↔ Auberdine, Auberdine ↔ Menethil Harbor, Menethil Harbor ↔ Southshore, Menethil Harbor ↔ Theramore, Zephras Isle ↔ Dalaran.

Zeppelin and boat trips are detected from your position: stand on the tower or dock for a few seconds and Pastime knows you are waiting. Once the ship carries you away, the trip has started.

## Commands

- `/pastime` – open or close the window
- `/pastime <game>` – start a game directly, for example `/pastime 2048`
- `/pastime records` – print your best scores to chat
- `/pastime routes` – open the route leaderboards
- `/pastime options` – open the settings
- `/pastime testflight [seconds]` – simulate a trip to try the landing alarm
- `/pastime dock` – show the nearest zeppelin tower or boat dock
- `/pastime help` – list all commands

Settings are also available under *Options → AddOns → Pastime*, and there is a key binding under *Key Bindings → AddOns*.

## Good to know

- Route names come from your game client, so the route leaderboards on a German client use German names.
- A round you started during a zeppelin or boat trip counts for that route once you arrive.
- If something does not work as expected, `/pastime diag` opens a report you can copy into a bug report.

## Credits and license

Dock positions for zeppelins and boats were cross-checked with the map data of ForeverDungeonJournal and Leatrix Maps. Thank you!

Pastime is free software under the MIT license.

---

# Pastime – Kurzweil für unterwegs (Deutsch)

**Langer Flug? Warten auf den Zeppelin? Pastime vertreibt dir die Zeit.**

Pastime bündelt 19 kleine Spiele in einem Fenster im klassischen Stil. Es merkt, wenn du eine Reise antrittst, und öffnet sich von selbst: beim Flugmeister, am Zeppelinturm oder am Schiffsanleger. Bei der Ankunft pausiert dein Spiel, und du entscheidest: weiterspielen oder beenden und werten. Jede Strecke hat ihre eigene Bestenliste.

**Funktionen**
- Öffnet sich auf Flügen, Zeppelin- und Schiffsreisen (abschaltbar) – oder per `/pastime`, Minimap-Knopf und Tastenbelegung.
- Merkt sich die Reisedauer jeder Strecke und zeigt die Restzeit; lange Spiele werden bei wenig Restzeit abgeblendet.
- Landealarm mit Pause, leisem Ton und großem Hinweis: **Weiterspielen** oder **Beenden & werten**.
- Bestenlisten: Top 10 pro Spiel und Schwierigkeit, Top 5 pro Spiel und Strecke. Abgebrochene Partien zählen nie.
- Markierung für kurze Flüge (1–2 Minuten) oder lange Reisen.
- Während des Spiels gehört die Tastatur dem Spiel – Chat, Screenshot und Lautstärke funktionieren weiter. Im Kampf pausiert das Spiel sofort.
- Klassischer Look, leise Spielgeräusche, deutsche und englische Texte, keine Bibliotheken, keine Datenübertragung.

**Die Spiele**
- *Geschicklichkeit:* Windnatter, Windreiter, Kodo-Sprint, Kobold-Hauen, Angeln, Steinschlag, Mauerbrecher, Murloc-Invasion
- *Knobeln:* Goblin-Minenfeld, Totem-Echo, Runenpaare, Edelstein-Code, Wortraten (deutsche Wortliste), Vier in einer Reihe, 2048, Edelsteine
- *Würfel & Karten:* Goblin-Blackjack, Tavernenwürfel, Solitär

**Befehle:** `/pastime` öffnet das Fenster, `/pastime hilfe` zeigt alle Befehle. Die deutschen Befehle (`rekorde`, `strecken`, `testflug`, `hafen` …) funktionieren ebenfalls. Einstellungen findest du unter *Optionen → AddOns → Pastime*.
