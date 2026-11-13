# Pastime – ToDo bis zur Vollversion 1.0.0

Diese Liste muss abgehakt sein, bevor `v1.0.0` getaggt wird.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` lässt alle `*.md` weg.)

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

### Allianz
- [ ] Mit einem Allianz-Charakter kurz Vier in einer Reihe, Minenfeld, Runenpaare und einen Kartenrücken ansehen.

Zum Schluss: `/pastime debug` aus, `/reload`, dann Screenshots und Protokoll auswerten lassen.

## 2. Gesamtprüfung
- [ ] Auswahlfenster: Liste, Kategorien, Markierungen kurz/lang, Details, Bestenliste
- [ ] Reiserekorde-Ansicht, Landedialog, Landealarm
- [ ] Optionen → AddOns → Pastime, Minimap-Knopf, Addon-Fach, Tastenbelegung
- [ ] `/pastime hilfe` (DE) und `/pastime help` (EN)

## 3. Offene Entscheidungen
- [ ] Blackjack: Knopf „Kasse machen“ (Lauf freiwillig beenden und Höchststand werten)?
- [ ] Layout-Prüfer im Release lassen (nur im Debug-Modus) oder entfernen?
- [ ] Fraktions-Thema für Horde und Allianz (in Arbeit)

## 4. CurseForge
- [ ] Beta-Datei geprüft: Spielversion 1.60.1, Changelog sauber formatiert, Zip enthält nur den Ordner `Pastime` ohne `tests` und `media`
- [ ] Logo als PNG hochgeladen (nicht webp)
- [ ] Screenshots für die Galerie
- [ ] Haltestellen-Koordinaten selbst nachmessen statt der Daten aus ForeverDungeonJournal und Leatrix Maps (im README genannt)

## 5. Release
- [ ] README (= CurseForge-Beschreibung) an die Änderungen anpassen, Link zu den GitHub-Issues ergänzen
- [ ] CHANGELOG: Abschnitt 1.0.0 aktualisieren
- [ ] Version in `Pastime.toc` und `Core.lua` prüfen
- [ ] Dateiliste der `.toc` prüfen
- [ ] Secret-Scan über die ganze Historie
- [ ] Tag `v1.0.0`, GitHub-Release mit Zip
