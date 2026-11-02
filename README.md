# Meine Heatmap

Flutter-App (Android, später iOS), die deinen Google-Maps-Zeitachsen-Export als Heatmap auf einer
OpenStreetMap-Karte anzeigt. Standortdaten bleiben auf dem Gerät. Die App lädt nur Kartenkacheln
von `tile.openstreetmap.org` (HTTPS).

## Daten exportieren
- **Android:** Einstellungen → Standort → Standortdienste → Zeitachse → „Zeitachsendaten exportieren“
- **iPhone:** Google Maps → Profilbild → Deine Zeitachse → ⋯ → Einstellungen → „Zeitachsendaten exportieren“

Dann in der App auf „Datei importieren“ tippen. Unter Android geht auch „Teilen“/„Öffnen mit“ → Meine Heatmap.
Unterstützt werden außerdem alte Takeout-Dateien (`Records.json`, Semantic Location History).

## Entwicklung (Windows)
Flutter-SDK liegt unter `C:\dev\flutter` (`C:\dev\flutter\bin` in den PATH aufnehmen).

1. [Android Studio](https://developer.android.com/studio) installieren und einmal starten (installiert das Android SDK)
2. `flutter doctor --android-licenses` und `flutter doctor`
3. Am Handy: Entwickleroptionen → USB-Debugging aktivieren, per USB verbinden
4. `flutter run` (oder `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`)

Tests: `flutter test` · Analyse: `flutter analyze`

## Am PC testen (Chrome)
Im Browser werden importierte Daten nicht gespeichert; nach dem Neuladen sind sie weg.

1. `dart run tool/generate_sample_data.dart` erzeugt erfundene Probedaten in `sample_data/`
   (Android 2025–26, iPhone 2024, Takeout Records 2023, Takeout Semantic 2022)
2. `flutter build web`
3. `dart run tool/serve_web.dart` und dann http://localhost:8080 öffnen
4. „Datei importieren“ und eine Datei aus `sample_data/` wählen; weitere Dateien mit „Hinzufügen“ ergänzen

## Aufbau
- `lib/data/parsers/`: Erkennung und Parsing der Exportformate
- `lib/data/point_store.dart`: kompakte Binärablage der Punkte
- `lib/heatmap/`: Aggregation pro Zoomstufe und Rendering der Heatmap als Kartenkacheln
- `lib/ui/`: Karte, Filter, Einstellungen
- `android/.../MainActivity.kt`: Empfang geteilter Dateien
