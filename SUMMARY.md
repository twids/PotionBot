# PotionBot

Two automatically maintained macros for WoW Forever beta:

| Macro | Out of combat | In combat |
| --- | --- | --- |
| HealthPotionBot | Food | Healthstone or healing potion |
| ManaPotionBot | Water | Mana gem or mana potion |

Secure combat/nocombat conditions choose the action; bag selections and macro
writes happen outside combat. Healthstones and mana gems have priority.

Open /pb to enable the macros, prefer buff food while Well Fed is missing,
and arrange food stats with Up/Down buttons. Spirit is included. The order
is saved. With Well Fed already active, plain food is preferred.

Install under Interface/AddOns/PotionBot, /reload, and put the macros on your
action bars. Use /pb status or /pb diagnose for selection details.

Targets Forever Interface 16001 with English tooltip parsing. Local Lua 5.1
tests pass; live compatibility still requires in-game checks. See README.md
for validation, fallback behavior, supported stats and limitations.
