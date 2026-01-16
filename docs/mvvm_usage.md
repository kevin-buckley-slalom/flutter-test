# MVVM usage notes

This dataset is designed for straightforward MVVM consumption with variant support:

- Model: `Pokemon` data class mirrors the JSON structure (`number`, `name`, `base_name`, `variant`, `generation`, `types`, `stats`).
- Repository/data source: load `data/pokemon.json` once, and expose helpers that wrap the lookup maps for O(1) access by number, name, or base_name.
- ViewModel: surface immutable, presentation-ready models (e.g., `PokemonDetailViewModel`) that select or filter the list/map and format strings for UI.

Suggested class sketch (language-agnostic):

```
class PokemonStats {
  int total, hp, attack, defense, spAtk, spDef, speed;
}

class Pokemon {
  int number;              // Shared by variants
  String name;             // Full display name (e.g., "Alolan Rattata")
  String baseName;         // Base name without variant (e.g., "Rattata")
  String? variant;        // Variant identifier or null for base form
  int generation;
  List<String> types;
  PokemonStats stats;
}

interface PokemonRepository {
  List<Pokemon> all();
  List<Pokemon> byNumber(int number);        // Returns all variants
  Pokemon? byNumberAndVariant(int number, String? variant);
  Pokemon? byName(String name);
  List<Pokemon> byBaseName(String baseName); // Returns all variants
  List<Pokemon> getVariants(int number);     // Helper for variants
}
```

Loading tips
- Use the list for ordered iteration (e.g., dex browsing).
- Use the maps for fast detail fetches.
- Cache deserialized objects; the dataset is small enough to hold in memory.
- `pokemon_by_number.json` returns lists to handle variants (multiple entries per number).

Variant handling
- Variants share the same `number` but are distinct instances with different types/stats.
- Use `base_name` for hierarchical grouping (e.g., show all forms of Rattata).
- Use `variant` field to distinguish forms (null = base form, string = variant name).
- Access all variants: `byNumber(19)` returns both "Rattata" and "Alolan Rattata".
- Access specific variant: `byNumberAndVariant(19, "Alolan")` or filter by `variant` field.

Filtering examples
- By generation: `all().where(p -> p.generation == 1)`
- By type: `all().where(p -> p.types.contains("Fire"))`
- By speed threshold: `all().where(p -> p.stats.speed >= 100)`
- Base forms only: `all().where(p -> p.variant == null)`
- Variants only: `all().where(p -> p.variant != null)`
- Specific variant: `all().where(p -> p.variant == "Alolan")`
- All forms of a Pokémon: `byBaseName("Rattata")`

