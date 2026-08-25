# qbx_3dprinter

3D Printer resource for FiveM (QBox Framework) supporting ox_inventory, ox_target, and ox_lib.

## Dependencies
- `qbx_core`
- `ox_lib`
- `oxmysql`
- `ox_target`
- `ox_inventory`

## Features
- Interactive 3D printer placement with raycast & rotatable object preview
- NUI dashboard managing storage materials (Plastic, Metal, Batteries) and printer condition
- CAD blueprint system (purchasable via UI CAD store or blackmarket)
- Item manufacturing with configurable print times (tools, weapon attachments, firearms)
- Visual 3D prop attached to the printer showing the current item being printed
- Repair mechanics, material extraction, and packing printer back to inventory
- Multi-language support: Czech (`cs`) and English (`en`)

## Installation

1. Copy `qbx_3dprinter` into your `resources` directory.
2. Import `install/database.sql` into your database.
3. Add item definitions from `install/items_ox_inventory.lua` into `ox_inventory/data/items.lua`.
4. Copy images from `icons/` to `ox_inventory/web/build/default/html/images/`.
5. Add `ensure qbx_3dprinter` to your `server.cfg`.

## Configuration

All settings are configured in `config/config.lua` and `config/recipes.lua`:

- `Config.Language` - Active language (`cs` or `en`)
- `Config.MaxPrintersPerPlayer` - Max active placed printers per player
- `Config.Durability` - Durability loss per print and repair costs
- `Config.Blackmarket` - Blackmarket location and inventory catalog
- `Config.ShopBlueprints` - CAD blueprints list in the NUI store
- `Config.Recipes` - Item recipes, required materials, print duration, and blueprints
