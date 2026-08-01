# Molecyou

Molecyou is a SwiftUI iOS and iPadOS app for learning the biology behind health, fitness, sleep, and activity. It uses HealthKit categories only to recommend educational topics, then connects those topics to curated systems, proteins, and public AlphaFold DB reference structures.

## Prerequisites

- Xcode 26 or newer
- iOS 18 or newer deployment target
- Swift 6 language mode
- HealthKit capability enabled for the app target

## Setup

Open `Molecyou.xcodeproj` in Xcode and run the `Molecyou` scheme. Demo mode works in Simulator without HealthKit authorization or network access.

Because Xcode was open, project-file edits were intentionally not applied by Codex. In the app target settings, add:

- Swift Language Version: Swift 6
- HealthKit capability
- `NSHealthShareUsageDescription`: `Molecyou reads workout, activity, sleep, heart-related, respiratory, oxygen saturation, and cardio fitness categories to recommend educational biology topics. HealthKit data stays on this device and is never used for advertising.`
- `NSHealthUpdateUsageDescription`: `Molecyou does not write HealthKit data.`
- Code signing entitlements file: `Molecyou.entitlements`

## Demo Mode

Onboarding defaults to demonstration mode. Demo snapshots are explicitly labeled and never silently substitute for missing real HealthKit values.

## Physical Device

Run on a device with HealthKit available, complete onboarding, disable demonstration mode, and use the HealthKit authorization screen. Molecyou requests read-only access to workouts, active energy, heart-rate summaries, sleep, respiratory rate, oxygen saturation, and VO2 max when available.

## AlphaFold DB

`AlphaFoldDBClient` requests public prediction metadata from `https://alphafold.ebi.ac.uk/api/prediction/{accession}` and downloads mmCIF or BCIF files when available. Structures are cached on disk and can be cleared from Library or Profile.

## Molecular Viewer

The app bundles Mol* `5.10.1` locally under `Resources/MolStar`. Swift downloads and caches AlphaFold mmCIF files, then passes the cached mmCIF text into the `WKWebView`; JavaScript creates a local Blob URL and loads it with Mol* `loadStructureFromUrl`. This keeps HealthKit data fully local and lets each protein render from its actual public AlphaFold reference coordinates.

## Testing

Run unit tests with the `MolecyouTests` target and UI tests with `MolecyouUITests`. Tests cover health-context rules, AlphaFold decoding, graph/search behavior, greeting/formatting, onboarding, and demo search navigation.

## Known Limitations

- Native representation and color pickers are wired into the viewer command bridge; advanced style editing still relies on Mol* viewport tools.
- The bundled knowledge graph is starter educational content and should be medically/scientifically reviewed before App Store release.
- HealthKit read permission cannot reveal whether individual read categories were denied; missing data is shown as missing.
