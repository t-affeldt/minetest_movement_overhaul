# Combat & Movement Overhaul (CMO)
This is a modular and comprehensive overhaul of two core components.
The collection of features aims to make combat more strategic and dynamic.
Damage is tweaked so that position and timing matters while the variety of movement modes offers new ways to engage.

## Features

### CMO Attack Overhaul
- additional sound effects
- elevated attacks do additional knockback (based on gravity)
- increased knockback while in the air
- backstabs against players do increased damage
- bonus damage based on relative movement speed
- missed punches cost stamina
- no damage dealt if out of stamina

### CMO Blood Effects
- particle effects upon taking damage, based on damage type
- particle effect when low on health
- taking damage has a chance to place blood on the ground

### CMO Camera Overhaul
(only enabled in singleplayer by default)
- 3rd person camera follows lazily instead of centering on player

### CMO Dodge
- double-tap on any direction key to initiate dodge (unless sneaking)
- costs stamina and can only be performed if sufficient stamina is left
- dodge moves player into specified direction quickly
- short time of being invulnerable and unpointable
- melee PvP damage is delayed until after punch animation

### CMO Sprint
- Hold W and tap A and D simultaneously to start sprinting (until you release W or run out of stamina)
- movement commitment: accelerating, breaking, and turning takes time
- tap Shift while sprinting to stop and start sliding

### CMO Stamina
- system compatible with other sprint mods (so far: *hbsprint, wadsprint, sprint_lite, real_stamina*)
- stamina consumption reduces satiation (supported: *hbhunger*, *mcl_hunger*)

### CMO Movement Tweaks
- greatly reduced movability while in the air (unless allowed to fly)
- muted footstep sounds while sneaking
- nametag hidden while sneaking
- position on minimap hidden while sneaking
- walk animations now consider player speed
- "mining" the air will now only play a short punch animation (in 3rd person)

### CMO Effects
- vignette effect based on player health
- desaturation based on health, stamina, and mana
- heartbeat sound on low health
- particles and sound effect when low on mana

### CMO HUD Additions
- particles indicate the amount of damage dealt
- new inidcator shows how much equipped weapon has charged up since the last punch
- completely filled bars of supported mods are hidden (so far: *mana, hbhunger, mcl_hunger*), requires *hudbars*

## Key Bindings
- Hold __W__ and tap __A + D__ -- Start sprinting
- *(While sprinting)* Release __W__ -- Stop sprinting
- *(While sprinting)* Tap __Shift__ -- Stop sprinting, start sliding
- Double-tap __W, A, S,__ or __D__ -- Dodge in that direction

## License
(c) 2023 Till Affeldt

Code licensed under __GNU LGPL v3__. A copy of the terms can be found in this project directory.

Media assets licensed under __CC BY-SA 4.0__ which can be found [here](https://creativecommons.org/licenses/by-sa/4.0/legalcode). Check individual mods for media sources. Made by myself if unspecified.

Font used for floating damage indicators: [CatV](https://fontlibrary.org/en/font/catv-6x12-9) by "HolyBlackCat", CC BY-SA 3.0.