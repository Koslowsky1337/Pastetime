# Pastime – ToDo bis zur Vollversion 1.0.0

Diese Liste muss abgehakt sein, bevor `v1.0.0` getaggt wird.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` nennt `TODO.md` und `README.md` ausdrücklich und lässt zusätzlich alle `*.md` weg.)

## 0. Reparaturen nach der Gesamt-Evaluation (14.11.)

- [x] Paket 1: Tastatur bleibt im Kampf frei, auch auf dem Spielende-Bildschirm
- [x] Paket 2: Release-Unterlagen (README, Changelog, `.pkgmeta`, Credits, Feedback-Link)
- [x] Paket 3: Versionsnummer kommt aus dem Tag (`@project-version@` in der TOC; ungepackt zeigt das Addon „dev“)
- [x] Paket 4: Zeppelin und Schiff (Anleger, Reload unterwegs, heruntergefallen, Ruhestein, Tod), Strecke löschen
- [ ] Paket 5: Sprache und Formate (Zahlen, Datum, Ortsnamen wie im Client)
- [ ] Paket 6: Spiel-Kleinigkeiten
- [ ] Paket 7: Lesbarkeit und Farbschwäche
- [ ] Paket 8: Tests härten
- [ ] Bot- und Glücksspiele: Gegner macht Fehler, man kann gewinnen

### Dazu im Spiel prüfen
- [ ] **Kampf auf dem Endbildschirm:** „Im Kampf ausblenden“ aus, eine Partie verlieren, angreifen lassen – Bewegen und Zaubern gehen sofort.
- [ ] **Zeppelin, ganz normal:** warten, abfahren, ankommen – Strecke und Dauer stimmen (die Erkennung wurde umgebaut). Danach `/pastime diag` 📸.
- [ ] **Zeppelin ohne Warten:** erst im letzten Moment aufspringen – die Reise wird trotzdem erkannt.
- [ ] **`/reload` auf dem Zeppelin:** bei der Ankunft geht kein Fenster auf und es steht keine Reise im Status.
- [ ] **Am Anleger stehen bleiben:** Fenster schließen, 11 Minuten warten – es öffnet sich nicht erneut.
- [ ] **Reiserekorde:** „Strecke löschen“ fragt nach und löscht erst beim zweiten Klick 📸.

## 1. Prüfung im Spiel (16 Spiele)

Im Spiel bestätigt sind bisher: Windnatter, Windreiter, Kodo-Sprint.

Vorher: `/reload`, dann `/pastime debug`. Das Debug-Fenster prüft alles, was angeklickt wird.
Zeigt es bei „Layout“ eine Zahl über 0: Screenshot.
Für jedes Spiel einmal: Details in der Auswahl ansehen, kurze Runde, einmal P und weiter, Spielende ansehen.
📸 = Screenshot machen.

### Geschicklichkeit
- [ ] **Kobold-Hauen:** Einblendungen „+10“, „+30“, „-20“ erscheinen über dem Schacht 📸. Nach P und „Weiter“ kommt der Countdown.
- [ ] **Angeln:** zehn Würfe; unter 300 Punkten steht am Ende „Spiel vorbei“ 📸.
- [ ] **Steinschlag:** aufliegender Stein lässt sich noch kurz schieben; Countdown nach Pause; Seitenleiste zeigt „P/Esc: Pause“ 📸.
- [ ] **Mauerbrecher:** Seitenleiste zeigt „Stufe“; Countdown nach Pause.
- [ ] **Murloc-Invasion:** Countdown nach Pause.

### Knobeln
- [ ] **Goblin-Minenfeld:** „Leicht“ und „Mittel“; Flaggen per Rechtsklick 📸.
- [ ] **Totem-Echo:** Steinrahmen der vier Totems vollständig sichtbar 📸.
- [ ] **Runenpaare:** falsches Paar aufdecken, sofort dritte Karte anklicken – Paar geht zu, neue Karte auf.
- [ ] **Edelstein-Code:** einmal lösen oder 10 Versuche; Erklärung rechts passt in ihren Platz 📸.
- [ ] **Wortraten:** ein Wort raten; P ist ein Buchstabe, Esc pausiert.
- [ ] **Vier in einer Reihe:** auf „Schwer“; die KI macht keine spürbare Denkpause.
- [ ] **2048:** Kacheln schieben 📸.
- [ ] **Edelsteine:** ungültigen Tausch versuchen – „Kein Treffer – Zug zurück“ ist mitten auf dem Feld lesbar 📸.

### Würfel & Karten
- [ ] **Goblin-Blackjack:** Einsatzknöpfe wachsen mit dem Gold 📸; nach `/reload` bleibt das Gold; alles verspielen – Spielende zeigt „Höchster Goldstand“ 📸; Farbzeichen ♥♦♠♣ auf den Karten sichtbar.
- [ ] **Tavernenwürfel:** Knopf heißt „Würfeln (2)“.
- [ ] **Solitär:** Karte und ganzen Stapel ziehen; Klick auf ein Ass legt es auf seinen Farbplatz; bei überdeckten Karten sind Wert und Farbzeichen sichtbar 📸.

### Testflug
- [ ] `/pastime testflug 40`, Kobold-Hauen oder Steinschlag starten, nochmal `/pastime testflug` – nach „Weiterspielen“ kommt der Countdown.

### Horde und Allianz
- [ ] Horde: Fenster mit roten Akzenten und Horde-Wappen neben „Pastime“ 📸.
- [ ] Mit einem Allianz-Charakter: Fenster blau mit Allianz-Wappen 📸; Greifenflug, Widder-Sprint und Glocken-Echo statt Windreiter, Kodo-Sprint und Totem-Echo 📸; Windnatter auf grüner Wiese; Angeln mit Elwynn-Fischen; Vier in einer Reihe, Minenfeld, Runenpaare und Kartenrücken mit Allianz-Motiven.

Zum Schluss: `/pastime debug` aus, `/reload`, dann Screenshots und Protokoll auswerten lassen.

## 2. Gesamtprüfung
- [ ] Auswahlfenster: Liste, Kategorien, Markierungen kurz/lang, Details, Bestenliste
- [ ] Reiserekorde-Ansicht, Landedialog, Landealarm
- [ ] Optionen → AddOns → Pastime, Minimap-Knopf, Addon-Fach, Tastenbelegung
- [ ] `/pastime hilfe` (DE) und `/pastime help` (EN)

## 3. Offene Entscheidungen
- [ ] Blackjack: Knopf „Kasse machen“ (Lauf freiwillig beenden und Höchststand werten)?
- [ ] Layout-Prüfer im Release lassen (nur im Debug-Modus) oder entfernen? (Evaluation: drin lassen – er läuft nur im Debug-Modus und ist begrenzt.)
- [ ] Markennamen in Dateinamen und Befehls-Aliasen (`Games\Tetris.lua`, `/pastime tetris`, `kniffel`, `bejeweled` …): lassen oder umbenennen? Angezeigt wird keiner davon.
- [ ] Logo: `media/logo.png` und `logo.svg` enthalten C2PA-Herkunftsdaten („erstellt mit Claude“). Drin lassen oder entfernen?
- [x] Fraktions-Thema für Horde und Allianz (Stufe 3 umgesetzt, Prüfung im Spiel steht unter 1.)

## 4. CurseForge
- [ ] Beta-Datei geprüft: Spielversion 1.60.1, Changelog sauber formatiert, Zip enthält nur den Ordner `Pastime` ohne `tests`, `media`, `README.md` und `TODO.md` (ob CurseForge das Muster `*.md` versteht, steht nicht in deren Doku; `CHANGELOG.md` darf im Zip liegen)
- [ ] GitHub-Repo: Beschreibung und Topics setzen (beides ist leer)
- [ ] Logo als PNG hochgeladen (nicht webp)
- [ ] Screenshots für die Galerie
- [ ] Haltestellen-Koordinaten selbst nachmessen oder die Autoren fragen: 21 von 24 Einträgen stammen aus ForeverDungeonJournal (Exehn), 3 aus Leatrix Maps (im README jetzt so genannt)

## 5. Release
- [x] README (= CurseForge-Beschreibung) an die Änderungen anpassen (auch: Horde/Allianz-Varianten), Link zu den GitHub-Issues ergänzen – danach den Text auf der CurseForge-Seite ersetzen
- [ ] CHANGELOG: zum Release oben den Abschnitt `1.0.0` anlegen (jetzt steht dort `1.0.0-beta2`, ganz unten die Funktionsübersicht)
- [x] Version in `Pastime.toc` und `Core.lua` prüfen (kommt jetzt aus dem Tag; im Beta-Zip nachsehen, ob in der TOC die Tag-Version steht)
- [x] Dateiliste der `.toc` prüfen (29 Einträge, alle vorhanden, keine doppelt)
- [x] Secret-Scan über die ganze Historie (14.11.: keine Treffer; jeder neue Commit wird einzeln geprüft)
- [ ] Tag `v1.0.0`, GitHub-Release mit Zip
