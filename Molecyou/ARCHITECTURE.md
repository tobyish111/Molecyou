# Architecture

Molecyou uses a feature-based SwiftUI architecture with explicit domain boundaries.

- `App`: app shell, dependency injection, root routing, and tab stacks.
- `Domain`: value models, starter graph, search, health-context engine, formatters.
- `Core/HealthKit`: read-only HealthKit manager plus demo provider.
- `Core/AlphaFoldDB`: metadata client, structure download, retry, and file cache.
- `Core/Persistence`: SwiftData models and repository abstraction.
- `Core/MolecularViewer`: reusable `WKWebView` bridge.
- `Features`: onboarding, Today, Atlas, Explore, system detail, protein detail, molecular viewer, Library, and Profile.

HealthKit data never enters networking code. AlphaFold requests know only UniProt accessions.
