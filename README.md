# mu-licenseplate

A QBCore FiveM resource that replaces default GTA5 license plates with authentic **Mauritius (🇲🇺) formatted plates** and adds a full NLTA-style custom plate purchase system.

---

## Features

- **Auto-generated standard plates** — every vehicle gets a Mauritius-format plate (`AB 1234`) on first entry, persisted in the database
- **NLTA Custom Plate Shop** — in-world interaction zone where players can purchase personalised plates
- **Old Series** — 1–2 letters + 1–4 numbers (e.g. `AB 123`) — mirrors real NLTA Specific Registration Marks
- **New Series** — extended formats including 3–6 letters + digits or a custom name up to 8 characters
- **Assign system** — players can own multiple custom plates and switch which one is shown on their vehicle
- Letters **I, O, Q** are excluded per NLTA convention

---

## Plate Formats

### Standard (auto-assigned)
| Format | Example | Notes |
|--------|---------|-------|
| `XX NNNN` | `AB 1234` | 2 letters + space + 4 digits |

### Custom — Old Series (`$25,000`)
| Format | Example |
|--------|---------|
| 1–2 letters + 1–4 digits | `AB 123`, `M 4` |

### Custom — New Series
| Type | Format | Example | Price |
|------|--------|---------|-------|
| 3L4N | 3 letters + 4 digits | `ABC 1234` | $50,000 |
| 4L4N | 4 letters + 4 digits | `ABCD1234` | $75,000 |
| 5L4N | 5 letters + 4 digits | `ABCDE123`* | $100,000 |
| 6L3N | 6 letters + 3 digits | `ABCDEF12`* | $125,000 |
| name | Custom name ≤ 8 chars | `MAURITIUS` | $150,000 |

\* Truncated to 8 characters to fit GTA5's plate limit.

---

## Dependencies

| Resource | Required |
|----------|----------|
| [qb-core](https://github.com/qbcore-framework/qb-core) | ✅ |
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ |
| [qb-menu](https://github.com/qbcore-framework/qb-menu) | ✅ |
| [qb-input](https://github.com/qbcore-framework/qb-input) | ✅ |

---

## Installation

1. **Import the SQL** — run `mu_licenseplate.sql` against your QBCore database
2. **Add the resource** — drop this folder into your `resources/` directory
3. **Start it** — add to `server.cfg`:
   ```
   ensure mu-licenseplate
   ```
4. **Configure** — edit `config.lua` to set your shop coordinates, prices, and payment type

---

## Configuration (`config.lua`)

```lua
-- NLTA office location in the game world
Config.ShopCoords = vector3(-559.71, -901.04, 24.0)

-- 'cash' or 'bank'
Config.PaymentType = 'bank'

-- Custom plate prices
Config.Prices = {
    old_series  = 25000,
    new_series  = {
        ['3L4N'] = 50000,
        ['4L4N'] = 75000,
        -- ...
    },
}
```

---

## File Structure

```
mu-licenseplate/
├── fxmanifest.lua
├── config.lua
├── mu_licenseplate.sql       ← import this into your database
├── shared/
│   └── utils.lua             ← plate generation & validation (both sides)
├── client/
│   └── main.lua              ← plate application, shop UI, proximity zone
└── server/
    └── main.lua              ← DB operations, purchase & assign handlers
```

---

## Usage

- **Walk up** to the NLTA blip on the map and press **E** to open the plate office menu
- **Purchase** an Old or New Series plate via the menu
- **Assign** it to your current vehicle from the same menu (must be in driver seat)
- Use the command `/plateoffice` as a fallback to open the menu anywhere

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `mu_plate_map` | Maps each GTA vehicle plate to its active Mauritius display plate |
| `mu_custom_plates` | Stores all purchased custom plates per citizen |

---

## License

MIT
