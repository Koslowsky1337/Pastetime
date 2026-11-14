# Pastime – ToDo bis zur Vollversion 1.0.0

Diese Liste muss abgehakt sein, bevor `v1.0.0` getaggt wird.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` lässt alle `*.md` weg.)

## 0. Reparaturen nach der Gesamt-Evaluation (14.11.)

- [x] Paket 1: Tastatur bleibt im Kampf frei, auch auf dem Spielende-Bildschirm
- [ ] Paket 2: Release-Unterlagen (README, Changelog, `.pkgmeta`, Credits, Feedback-Link)
- [ ] Paket 3: Versionsnummer kommt aus dem Tag
- [ ] Paket 4: Zeppelin und Schiff (Anleger, Reload unterwegs, heruntergefallen, Ruhestein)
- [ ] Paket 5: Sprache und Formate (Zahlen, Datum, Ortsnamen wie im Client)
- [ ] Paket 6: Spiel-Kleinigkeiten
- [ ] Paket 7: Lesbarkeit und Farbschwäche
- [ ] Paket 8: Tests härten
- [ ] Bot- und Glücksspiele: Gegner macht Fehler, man kann gewinnen

### Dazu im Spiel prüfen
- [ ] **Kampf auf dem Endbildschirm:** „Im Kampf ausblenden“ aus, eine Partie verlieren, angreifen lassen – Bewegen und Zaubern gehen sofort.

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
- [ ] Layout-Prüfer im Release lassen (nur im Debug-Modus) oder entfernen?
- [x] Fraktions-Thema für Horde und Allianz (Stufe 3 umgesetzt, Prüfung im Spiel steht unter 1.)

## 4. CurseForge
- [ ] Beta-Datei geprüft: Spielversion 1.60.1, Changelog sauber formatiert, Zip enthält nur den Ordner `Pastime` ohne `tests` und `media`
- [ ] Logo als PNG hochgeladen (nicht webp)
- [ ] Screenshots für die Galerie
- [ ] Haltestellen-Koordinaten selbst nachmessen statt der Daten aus ForeverDungeonJournal und Leatrix Maps (im README genannt)

## 5. Release
- [ ] README (= CurseForge-Beschreibung) an die Änderungen anpassen (auch: Horde/Allianz-Varianten), Link zu den GitHub-Issues ergänzen
- [ ] CHANGELOG: Abschnitt 1.0.0 aktualisieren
- [ ] Version in `Pastime.toc` und `Core.lua` prüfen
- [ ] Dateiliste der `.toc` prüfen
- [ ] Secret-Scan über die ganze Historie
- [ ] Tag `v1.0.0`, GitHub-Release mit Zip
