# FlightCard

Pilot-grade airport weather for iOS. Decoded METARs and TAFs, a wind dial with every runway drawn at its true heading, per-runway crosswind components with gusts, density altitude, and the official FAA airport diagram, built in SwiftUI on NOAA Aviation Weather Center data.

<table>
  <tr>
    <td><img src="docs/screenshots/kdab-dark.png" width="240" alt="KDAB airport card in dark mode"></td>
    <td><img src="docs/screenshots/kdab-light.png" width="240" alt="KDAB airport card in light mode"></td>
    <td><img src="docs/screenshots/forecast.png" width="240" alt="TAF forecast timeline"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/home.png" width="240" alt="Favorites with live flight category and wind"></td>
    <td><img src="docs/screenshots/diagram.png" width="240" alt="FAA airport diagram"></td>
    <td></td>
  </tr>
</table>

## Why

Most weather apps show the numbers. Pilots need to know what the numbers mean for the runway in front of them. FlightCard answers "which runway, and how much wind" at a glance, and keeps the raw METAR and TAF one scroll away so nothing is hidden behind the interpretation.

## Details a pilot would check

- **True vs. magnetic.** METAR winds are true. ATIS and tower winds are magnetic. AWC runway alignment is also true, so crosswind math lines up without conversion, and the dial is labeled true-north-up.
- **Gusts count.** Headwind and crosswind are computed separately for the steady wind and the gust, and gust crosswind is what gets checked against your limit.
- **No false precision.** Under 2 kt of head/tailwind reads as "near-direct crosswind," not a favored runway. The math was right before this rule existed, but it told pilots something misleading.
- **Parallels group correctly.** Runways within 3° share one label, sorted L/C/R. The data lists ORD's 04L and 04R a degree apart, which used to split them.
- **Exact altimeter.** AWC rounds the altimeter to whole hPa, which can be off by 0.01–0.02 inHg. FlightCard reads the exact value from the raw METAR's `A` group instead.
- **TEMPO means temporary.** Change groups only list what changes, so they inherit missing fields from the prevailing forecast before a flight category is computed, and they're drawn dashed so they read as "might happen."
- **Stale data is flagged.** A METAR older than 70 minutes means a missed hourly report, so the app says so.
- **Fog setup.** A temp/dewpoint spread of 2°C or less in VFR or MVFR gets a caution.

## Features

- Wind dial: HSI-style compass rose, runways at true heading, numbers at the approach end, wind pointer on the bezel, collision-aware labels for busy airports like BOS and ATL
- Favored runway with headwind, crosswind, and gusts
- Personal minimums: set a max crosswind and runways over it are flagged
- TAF timeline on a Zulu axis with a "now" marker and tap-for-details
- Official FAA airport diagrams from the d-TPP, with pinch and double-tap zoom
- Favorites showing live flight category and wind, with reorder and delete
- Light, dark, or system appearance; inHg or hPa

## Engineering

- SwiftUI, Swift concurrency, `@Observable`, iOS 17+
- Decoding built against real AWC responses, handling the messy parts: `visib` as `"10+"` or a number, `wdir` as `"VRB"`, `204` for no data
- Respects AWC's rules: custom User-Agent, response caching to stay under the rate limit
- Runway grouping, wind components, density altitude, TAF decoding, and flight category thresholds live outside the views and are unit tested with Swift Testing (18 tests), including fixtures for ORD, ATL, and BOS

```
FlightCard/
  Models/     Metar, Taf, Airport
  Services/   AWCClient, DiagramService
  Logic/      WindCalc, DensityAltitude, RunwayGrouping
  Views/      SearchView, AirportCardView, WindDial, TafTimeline, ...
FlightCardTests/
```

## How I built it

Built with heavy AI assistance. My job was the parts AI gets wrong: checking every output against what a pilot actually sees, catching bugs like the ORD runway ordering and misleading crosswind wording, and making sure the logic that matters is tested.

## Data and disclaimer

Weather from the [NOAA Aviation Weather Center](https://aviationweather.gov/data/api/). Airport diagrams from the FAA digital Terminal Procedures Publication.

For situational awareness only. Not a substitute for an official weather briefing.

## About

Built by Ben Eccles, commercial pilot student at Embry-Riddle Aeronautical University, instrument rated.
