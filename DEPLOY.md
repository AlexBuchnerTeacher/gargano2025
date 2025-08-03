# Deploy-Anleitung für Gargano 2025 (GitHub Pages)

Diese Checkliste beschreibt, wie du Änderungen in der App speicherst und auf GitHub Pages veröffentlichst.

---

## 1. Änderungen speichern
- Stelle sicher, dass alle bearbeiteten Dateien in VS Code gespeichert sind
- Prüfe, ob Dateien an den richtigen Stellen liegen (`lib/screens/...`, `lib/widgets/...` usw.)

---

## 2. Optional: Clean & Abhängigkeiten neu laden
*(Notwendig nach Änderungen an pubspec.yaml)*

```bash
flutter clean
flutter pub get
