# Combat & Movement Overhaul (CMO)
This is an overhaul for Minetest's movement system.

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
- double-tap on any direction key to initiate dodge
- costs stamina and can only be performed if sufficient stamina is left
- dodge moves player into specified direction quickly
- short time of being invulnerable and unpointable
- melee PvP damage is delayed until after punch animation

### CMO Stamina + Sprint
- sprint mod with movement commitment
- accelerating, breaking, and turning takes time
- stamina system compatible with other sprint mods (so far: *hbsprint, wadsprint, sprint_lite, real_stamina*)

### CMO Movement Tweaks
- greatly reduced movability while in the air (unless allowed to fly)
- muted footstep sounds while sneaking
- nametag hidden while sneaking
- position on minimap hidden while sneaking

### CMO Effects
- vignette effect based on player health
- desaturation based on health, stamina, and mana
- heartbeat sound on low health
- particles and sound effect when low on mana

### CMO HUD Additions
- new inidcator showing how much the weapon has charged up again since the last punch
- hides completely filled bars of supported mods (so far: *mana, hbhunger*), requires *hudbars*

## License
Code licensed under GNU LGPL v3. Media assets licensed under CC BY-SA 4.0.
Check individual mods for media sources. (c) Till Affeldt, if unspecified.