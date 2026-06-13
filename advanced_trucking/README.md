# Corner Life RP Trucking & Logistics

Advanced FiveM trucking career resource with legal freight, discreet RP supply runs, cargo physics modifiers, trailer checks, truck condition, DOT interactions, company progression, and a tablet NUI.

## Install

1. Copy `advanced_trucking` into your server `resources` folder.
2. Import `database.sql` into your MySQL database.
3. Ensure `oxmysql` starts before this resource.
4. Add this to `server.cfg`:

```cfg
set mysql_connection_string "mysql://user:password@localhost/database?charset=utf8mb4"
set onesync on

ensure oxmysql
ensure advanced_trucking
```

OneSync is recommended because the server validates delivery location using server-side player coordinates.

## Framework

`Config.Framework = 'auto'` supports QBCore, ESX, or standalone fallback notifications/payout logging. Bank payments and fines require QBCore or ESX.

`oxmysql` is required for this version because the resource persists profiles, jobs, companies, trucks, employees, and logs.

## Player Use

- Command: `/trucking`
- Default key: `F7`
- Depot interaction: press `E` at public trucking depots

## Main Files

- `config.lua`: tiers, cargo, trailers, trucks, depots, licenses, payouts, police checks, random events
- `client.lua`: tablet callbacks, rig spawning, trailer checks, route markers, fuel/wear/damage/event logic
- `server.lua`: profiles, contracts, payouts, companies, licenses, inspections, logs
- `database.sql`: persistence tables
- `html/`: tablet UI

## Server Readiness Notes

- Import `database.sql` before starting the resource.
- Keep `advanced_trucking` folder name unchanged unless you also update references.
- Review `Config.PoliceJobNames` for your server's police job names.
- Review depot coordinates before launch if your map/MLO layout differs.
- Hidden destinations are configured for RP supply runs but only unlock through higher reputation owner-operator contracts.
