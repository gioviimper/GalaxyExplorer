# Code organization

All product text and source comments are in English. The app and widget extension use Xcode file-system synchronized groups, so new Swift files in their folders join the correct target automatically.

## App

- `App`: application entry point.
- `Domain/Planets`: planet models, the bundled catalog, ring bands and optional card content.
- `Features/SolarSystem`: the Home screen, overview scene and overview coordinator.
- `Features/PlanetDetail`: planet detail UI and the interactive SceneKit bridge. Coordinator extensions group callouts, gestures, motion and haptics; shared state and cleanup live in the coordinator file.
- `Features/Notifications`: permission and notification routing, preferences, fact scheduling and local sky events.
- `Features/Notifications/SkyEvents/Data`: network access, NASA parsers and IMCCE response schemas.
- `Features/Notifications/SkyEvents/Astronomy`: horizon math and conversion of validated data into local viewing opportunities.
- `Shared`: appearance, scene resources and interaction commands used across app features.
- `Resources`: app asset catalog.

## Widgets

- `GalaxyWidgets/Planet`: configurable Home widgets, their entries, provider, configuration and raster artwork.
- `GalaxyWidgets/ShootingStar`: Lock Screen widget, artwork, timeline and interactive intent.
- `GalaxyWidgets/Shared`: decorative widget background.
- `GalaxyWidgets/Resources`: widget asset catalog and texture JPEGs.
- `GalaxyWidgets/Configuration`: extension Info.plist.

The extension target and scheme are named `GalaxyWidgetsExtension`. The existing bundle identifier and `MarsWidgets` WidgetKit kind are intentionally retained so source renaming does not change installed widget identities. Do not rename those persisted identifiers as part of source cleanup.

## Content and event integration

Surface cards stay empty until actual API content is supplied; the relevant English TODO comments remain next to their mapping code. NASA meteor dates and eclipse catalog validation are separate from IMCCE response decoding and local visibility calculations. Network work stays out of view bodies, gesture handlers and frame callbacks.

Notifications remain opt-in. Local sky events use a saved approximate location and refresh on app opening; scheduled alerts do not require the app to remain open. This source organization does not add an APNs backend.
