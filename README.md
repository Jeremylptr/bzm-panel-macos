# BZM Trading Intelligence — Swift (Nativ)

Vollständige Neuschreibung der Python-App in **Swift + SwiftUI**.  
Kein Python, kein venv, keine Abhängigkeiten — eine **native macOS-App** zum Doppelklicken.

## Was die App macht

- **Live Forex-Preise** (EUR/USD, GBP/USD … via Yahoo Finance — kostenlos)
- **RSS-News** von 13 Quellen (ForexLive, Reuters, CNBC, MarketWatch …) mit automatischer Forex-Relevanzfilterung
- **Claude AI-Analyse** jeder News (Score 1–10, Richtung je Währungspaar, Urgency)
- **Tiefenanalyse** (Detail-Analyse mit Trade-Setup, Risiken, Makro-Faktor)
- **Wirtschaftskalender** (ForexFactory: diese Woche + nächste Woche)
- **Intelligence Scanner** (Opportunity Scores für 16 Forex-Paare + Währungsstärke-Index)
- **Einstellungen** (API-Keys, Paare, Intervalle) — in-App, kein Texteditor nötig

## Voraussetzungen

- macOS 13.0+
- Xcode 15+
- **Claude API-Key** (Anthropic) — kostenloser Test möglich

## Öffnen & Bauen

```
BZMTrading.xcodeproj öffnen → Scheme „BZMTrading" → ⌘R (Run)
```

Kein Cocoapods, kein SPM — **keine externen Packages nötig**.

## Konfiguration

Beim ersten Start erscheint das Einstellungsfenster (⚙ oben rechts).  
Dort Claude API-Key, Markt-Paare und Intervalle eintragen — wird gespeichert unter:

```
~/Library/Application Support/BZM/config.json
```

Alternativ: `config.example.json` nach dort kopieren und manuell bearbeiten.

## Verzeichnis

```
bzm-swift/
├── BZMTrading.xcodeproj/
├── BZMTrading/
│   ├── App.swift               ← @main Entry Point
│   ├── Models/
│   │   ├── Config.swift        ← JSON-Konfiguration
│   │   ├── NewsItem.swift      ← News + KI-Analyse
│   │   ├── PriceData.swift     ← Forex-Preise + Ticker-Map
│   │   ├── CalendarEvent.swift ← Wirtschaftsereignisse
│   │   └── ScannerResult.swift ← Opportunity Scores
│   ├── Services/
│   │   ├── AppState.swift      ← Zentraler Zustand (ObservableObject)
│   │   ├── DatabaseService.swift ← SQLite (eingebaut, kein Paket)
│   │   ├── NewsService.swift   ← RSS-Aggregator (XML-Parser)
│   │   ├── PriceService.swift  ← Yahoo Finance API
│   │   ├── CalendarService.swift ← ForexFactory API
│   │   ├── ClaudeService.swift ← Anthropic Claude REST
│   │   └── ScannerService.swift ← Opportunity-Score-Engine
│   └── Views/
│       ├── Theme.swift         ← Bloomberg-Farbschema
│       ├── MainView.swift      ← Hauptfenster + Top/Status-Bar
│       ├── NewsPanelView.swift ← News-Liste + Filter
│       ├── DetailPanelView.swift ← Detail + Tiefenanalyse
│       ├── PricePanelView.swift ← Live-Preistabelle
│       ├── CalendarPanelView.swift ← Kalender nach Tag gruppiert
│       ├── ScannerPanelView.swift ← Scanner + Währungsstärke
│       └── SettingsView.swift  ← Einstellungs-Sheet
└── config.example.json
```

## Vergleich zur Python-Version

| Feature | Python (`bzm-trading/`) | Swift (`bzm-swift/`) |
|---------|-------------------------|----------------------|
| Start   | `./install.sh` + `python main.py` | `.app` doppelklicken |
| Deps    | ~400 MB venv           | 0 (nur Apple-Frameworks) |
| Preise  | yfinance               | Yahoo Finance REST direkt |
| News    | feedparser             | Foundation XMLParser  |
| Daten   | peewee/SQLite          | SQLite C-API direkt   |
| GUI     | PyQt6                  | SwiftUI               |
| KI      | anthropic SDK          | REST-Calls direkt     |
