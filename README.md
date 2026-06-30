# QBCore Advanced Ambulance Job V2

Current version: `2.5.0`. See `CHANGELOG.md` for the complete release history.

Modern EMS/ambulance resource for QBCore servers with the default QBCore Pillbox preset and an optional Octavista Vespucci EMS configuration.

## Features

- Modern NUI EMS command tablet
- Death and unconscious overlay with respawn timer
- EMS alerts with route blips
- Patient lookup, treatment, revive, billing, and records
- Hospital check-in when not enough doctors are online
- Configurable hospitals, beds, garages, helipads, armory, prices, and timers
- Usable medical items: bandage, painkillers, IFAK, defib, medbag
- EMS stash, duty points, garage, and check-in target zones
- Octavista Vespucci EMS duty, check-in, stash, armory, boss, garage, helipad, bed, and respawn preset
- SQL-backed patient treatment history
- Clinical tests, blood collection, imaging, surgery, and structured medical reports
- LB Phone Health Care app for patient-owned reports
- Bookable health packages with cash, card, bank, and pay-at-hospital payment
- Patient booking tracking, invoices, published reports, and route guidance
- EMS booking queue with sample, scan, report, and completion milestones
- Tablet-managed pharmacy and hospital locations saved from current coordinates
- Self-migrating predefined packages and test pricing
- EMS package editor with custom plans and live percentage discounts

## Dependencies

- `qb-core`
- `qb-target`
- `qb-menu`
- `qb-input`
- `qb-phone` is optional for legacy billing mail
- `qb-management`
- `qb-inventory`
- `qb-progressbar`
- `oxmysql`
- `LegacyFuel` or replace the fuel export in `client/main.lua`
- `lb-phone` is optional and required only for the Health Care phone app

## Installation

1. Copy `qb-advanced-ambulance-v2` into your server `resources` folder.
2. Import `sql.sql` into your database.
3. Add this to `server.cfg`:

```cfg
ensure qb-advanced-ambulance-v2
```

4. For LB Phone support, start the phone before this resource:

```cfg
ensure lb-phone
ensure qb-advanced-ambulance-v2
```

5. Add the ambulance job to `qb-core/shared/jobs.lua` if your server does not already have it:

```lua
['ambulance'] = {
    label = 'EMS',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Trainee', payment = 75 },
        ['1'] = { name = 'Paramedic', payment = 100 },
        ['2'] = { name = 'Doctor', payment = 125 },
        ['3'] = { name = 'Surgeon', payment = 150 },
        ['4'] = { name = 'Chief', isboss = true, payment = 175 },
    },
},
```

6. Add missing items to `qb-core/shared/items.lua`:

```lua
['defib'] = { name = 'defib', label = 'Defibrillator', weight = 2500, type = 'item', image = 'defib.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'Restarts a patient heart rhythm' },
['medbag'] = { name = 'medbag', label = 'Medical Bag', weight = 3500, type = 'item', image = 'medbag.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'Portable EMS tablet and treatment kit' },
['stretcher'] = { name = 'stretcher', label = 'Stretcher', weight = 5000, type = 'item', image = 'stretcher.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'EMS stretcher equipment' },
['ifak'] = { name = 'ifak', label = 'IFAK', weight = 800, type = 'item', image = 'ifak.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'Individual first aid kit' },
```

## Commands

- `/emsalert [message]` sends an EMS alert.
- `/emstablet` opens the EMS command tablet while on duty.
- `/patient [id]` loads a patient into the tablet.
- `/revivep` revives the nearest patient while on duty.
- `/treatp` treats the nearest patient while on duty.

## Configuration

Edit `shared/config.lua` for:

- Hospital and clinic locations
- Check-in prices
- Minimum online EMS
- Death timer
- Revive and treatment rewards
- Garage and helicopter vehicles
- Armory items
- Item heal values
- Test catalog, surgery catalog, procedure duration, and X-ray machine models

## Clinical System

Load a nearby player with `/patient [id]`, open `/emstablet`, and use the Clinical tab. Completed procedures generate database-backed reports. The patient can read their own reports in the LB Phone `Health Care` app.

The included catalog covers examinations, vitals, CBC, metabolic panel, blood group, toxicology, urinalysis, ECG, X-ray, CT, MRI, ultrasound, trauma surgery, orthopedic surgery, cardiovascular surgery, neurosurgery, abdominal surgery, and wound surgery. Configure machine object models in `Config.Healthcare.xrayModels`.

## Packages And Booking Tracking

The LB Phone Health Care app provides four patient views: Book, Bookings, Reports, and Invoices. The included SQL seeds Essential, Cardiac, Trauma, and Complete health packages.

EMS manages package orders from the tablet Bookings tab. The controlled workflow is order placed, awaiting hospital visit, samples collected, scans completed, awaiting report, report published, and completed. Reports and invoices are visible only to the owning character.

Use the tablet Locations tab while standing at a service counter to add a pharmacy or hospital. Coordinates are captured automatically and stored in SQL; no config edit is needed. Locations can be enabled or disabled from the same screen.

Version 2.3.0 automatically creates and upgrades package-related tables at startup. `sql.sql` remains available for manual database installation.

## Automatic Updates

The server updater checks on startup and every 60 minutes, prints colored status in the FiveM console, downloads newer files, and restarts the resource after a successful installation.

Host an update manifest based on `update-manifest.example.json`, then add this before the resource ensure line in `server.cfg`:

```cfg
set qa_ambulance_update_url "https://your-domain.example/update-manifest.json"
set qa_ambulance_auto_update 1
set qa_ambulance_auto_restart 1
set qa_ambulance_update_interval 60
ensure qb-advanced-ambulance-v2-fixed
```

Run `emsupdate` in the server console for an immediate check. Players require the `command.emsupdate` ACE permission to run it in game. The interval is measured in minutes with a minimum of 15. Update URLs and file URLs must use HTTPS. The updater refuses unsafe paths and never overwrites `shared/config.lua`.

## GitHub Synchronization

`tools/sync-github.ps1` stages resource changes, creates a timestamped commit when needed, and pushes `main` to `origin`. Configure the private GitHub remote and authentication before scheduling this script.

## Octavista Vespucci EMS Preset

The active preset is:

```lua
Config.DefaultHospital = 'pillbox'
Config.MapPreset = 'qb_default_pillbox'
```

Configured Vespucci EMS points:

- `duty`: clock in/out
- `boss`: EMS management
- `stash`: EMS shared stash
- `armory`: EMS item shop
- `checkin`: public patient check-in
- `garage.menu`: ambulance garage menu
- `garage.spawn`: ambulance spawn
- `heli.menu`: helipad menu
- `heli.spawn`: helicopter spawn
- `beds`: treatment beds
- `respawn`: hospital respawn point

If your MLO package uses shifted interiors or a different shell position, stand at each spot in-game, use a vector command such as `/vector3` or `/vector4`, then update only the `vespucci` block in `shared/config.lua`.

## Integration Notes

QBCore forks differ on billing, inventory, fuel, and phone APIs. If your server uses different resources:

- Replace `exports['LegacyFuel']:SetFuel(...)` in `client/main.lua`.
- Replace `exports['qb-inventory']:OpenInventory(...)` in `server/main.lua`.
- Replace `qb-banking:server:CreateInvoice` if your banking resource uses another invoice event.
- Replace `qb-phone:server:sendNewMailToOffline` if your phone resource uses a different mail event.

## Suggested Resource Name

Keep the folder name as `qb-advanced-ambulance-v2` unless you also update any references in your server tooling.
