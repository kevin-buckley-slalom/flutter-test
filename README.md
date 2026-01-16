# ChampionDex

A modern, sleek, and user-friendly Flutter application for looking up Pokemon information, designed as a quick reference guide for competitive Pokemon play.

## Features

- **Pokemon List View**: Scrollable list of all Pokemon forms with at-a-glance details:
  - Pokemon name and National Dex number
  - Variant form badge (if applicable)
  - Type chips with color-coded styling
  - Base Stats Total (BST)
  - Placeholder images (ready for Pokemon sprites)

- **Pokemon Detail View**: Comprehensive information for each Pokemon:
  - Large Pokemon image (Hero animation transition)
  - Full Pokemon information (name, number, variant, generation)
  - Type chips
  - Horizontal bar charts for all base stats (HP, Attack, Defense, Sp. Atk, Sp. Def, Speed)
  - Type effectiveness visualization:
    - Immunities (0x damage)
    - Weaknesses (2x damage)
    - Resistances (0.5x damage)
    - Neutral matchups (1x damage)

## Architecture

The app follows Flutter's official MVVM architecture guidelines:

- **Data Layer**: Models, Services, and Repositories for data access
- **Domain Layer**: Use cases for business logic (type effectiveness calculation)
- **UI Layer**: Views and ViewModels following MVVM pattern
- **State Management**: Flutter Riverpod for reactive state management

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Ensure Pokemon data files are in `assets/data/`:
   - `pokemon.json`
   - `pokemon_by_number.json`
   - `pokemon_by_name.json`
   - `pokemon_by_base_name.json`

4. Run the app:
   ```bash
   flutter run
   ```

## Data

Pokemon data is generated from the scripts in `scripts/build_pokemon_data.py`. The data includes:
- All Pokemon forms and variants
- Base stats
- Type information
- Generation data

## Design

- **Theme**: Material Design 3
- **Primary Color**: Red shades
- **Secondary Color**: Blue accents
- **Type Colors**: Standard Pokemon type color palette
- **Responsive**: Optimized for mobile devices

## Project Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── theme/
│       ├── app_theme.dart
│       └── type_colors.dart
├── data/
│   ├── models/
│   ├── services/
│   └── repositories/
├── domain/
│   ├── use_cases/
│   └── utils/
└── ui/
    ├── pokemon_list/
    ├── pokemon_detail/
    └── shared/
```

## License

This project is for personal use.




