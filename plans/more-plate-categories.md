# More plate categories

Color each player nameplate from the first matching category. Every category gets its own group on the AddOns page, with a color and a Hide checkbox.

1. Party
2. Raid
3. Guild
4. Friends
5. Recent Allies
6. Other

A guildmate who is also a friend stays Guild. A friend who is also a recent ally stays Friends. You, NPCs, and secret units stay uncolored and unhidden.

Hide applies after the category is chosen. A hidden party member stays hidden for as long as they match Party.

Work is entirely in `PowerPlate/PowerPlate.lua`, plus the Notes line in `PowerPlate/PowerPlate.toc`.

## Categories

| Order | Key | Who | Test | Default color | Hide default |
| --- | --- | --- | --- | --- | --- |
| 1 | `party` | Your 5-person party, or your raid subgroup | `party1`–`party4`. Inside a raid those tokens are the subgroup. `UnitInSubgroup` agrees for a normal party. | `255, 105, 180` | off |
| 2 | `raid` | Everyone else in your raid | `UnitPlayerOrPetInRaid` | `80, 140, 255` | off |
| 3 | `guild` | Your guild | `UnitIsInMyGuild` | `80, 200, 120` | off |
| 4 | `friend` | Friend list | `UnitSelectionType(unit, true) == 8` | `255, 176, 64` | off |
| 5 | `recent` | Recent Allies, the former-group highlight | `UnitSelectionType(unit, true) == 16` | `83, 201, 255` | off |
| 6 | `other` | Any other player | `UnitIsPlayer` | `99, 99, 99` | on |

Other’s hide default matches today’s behavior. Existing `PowerPlateDB.other.hide` keeps working.

Battleground teammates are outside `UnitInParty` on this client. When `UnitPlayerOrPetInRaid` reports them, they use Raid.

## Classification

`Classify` today treats `UnitInParty` as Party. On Forever 1.60.1 that call is true for party and raid members, so the whole raid would match Party and Raid would never win. Replace `InMyParty` with the ordered tests below. A pet uses its owner's category, including Hide. Your pet follows you. A party or raid pet follows that player. Another player's pet follows that player, and a confirmed pet with no visible owner uses Other.

1. Secret unit, or a secret self check: `unknown`. Leave the plate alone.
2. `UnitIsUnit(unit, "player")`: `self`.
3. `UnitIsPlayer` secret: `unknown`.
4. `UnitIsPlayer` false: `npc`.
5. Same unit as `party1`–`party4`: `party`. A secret compare on those tokens returns `unknown`, as today.
6. `UnitInSubgroup` while `UnitPlayerOrPetInRaid` is false: `party`. This covers a normal party if the party tokens were missing. Inside a raid, only step 5 counts as Party. If a `/powerplate` dump shows `UnitInSubgroup` true for the whole raid, ignore it there.
7. `UnitPlayerOrPetInRaid`: `raid`. Use this boolean. `UnitInRaid` is identity-restricted and comes back secret in combat.
8. `UnitIsInMyGuild`: `guild`.
9. Extended selection type `8`, or a public `UnitName` that `C_FriendList.GetFriendInfo` recognizes: `friend`.
10. Extended selection type `16`: `recent`.
11. Otherwise: `other`.

`UnitIsFriend` means the unit is friendly. It does not mean the friend list. `C_FriendList.IsFriend` and `C_RecentAllies.IsRecentAllyByGUID` need a GUID, and `UnitGUID` is secret while identity is restricted. Selection type stays readable, which is also what paints the default plate.

A missing unit’s selection type is `4` or `5`. Those stay Other. A dead friend can report type `9` instead of `8`; the `GetFriendInfo` name check keeps them in Friends when the name is public. The client paints type 8 and type 16 the same cyan, so Friends uses its own amber default.

One list drives classification, colors, hide defaults, and the options page:

```lua
local CATEGORIES = {
  { key = "party",  label = "Party",          color = PARTY_COLOR,  hide = false },
  { key = "raid",   label = "Raid",           color = RAID_COLOR,   hide = false },
  { key = "guild",  label = "Guild",          color = GUILD_COLOR,  hide = false },
  { key = "friend", label = "Friends",        color = FRIEND_COLOR, hide = false },
  { key = "recent", label = "Recent Allies",  color = RECENT_COLOR, hide = false },
  { key = "other",  label = "Other Players",  color = OTHER_COLOR,  hide = true },
}
```

## Settings page

Escape → Options → AddOns → Power Plate. Six groups, in the order above. A gold rule separates each group. Walking `CATEGORIES` builds them, stacked under one another. The fixed Y positions in `BuildOptions` go away.

Each group contains:

- The category name.
- A color swatch and a Color button, using the existing `OpenColorPicker`.
- A Hide checkbox under the color row.

`StoreHide` and the hide reader take a category key. `RefreshOptionsPanel` updates every swatch and every checkbox.

## Saved variables and paint

`PowerPlateDB[key].color` and `PowerPlateDB[key].hide` store each category. A color or hide equal to that category’s default is removed, and an empty category table is pruned, same as today.

`ColorForKind` returns the winning category’s color when its Hide is off. `ApplyHidden` runs for every winning category whose Hide is on, including Party. `LockHidden`, the Show hook, and the plate `OnUpdate` today special-case `other`. They follow the winning category instead. Unchecking Hide restores the plate and paints its color. You, NPCs, and `unknown` are never hidden.

When `OnUpdate` sees the category change, repaint. A plate moving onto a hidden category is hidden. A plate moving onto a shown category is restored and colored.

Refresh on:

- `GROUP_ROSTER_UPDATE` for Party and Raid. Already registered.
- `GUILD_ROSTER_UPDATE` and `PLAYER_GUILD_UPDATE` for Guild.
- `FRIENDLIST_UPDATE` for Friends.
- `RECENT_ALLIES_CACHE_UPDATE` and `RECENT_ALLY_DATA_UPDATED` for Recent Allies, because the highlight can change while a plate is on screen.

`/powerplate` logs the winning category and, for players, the extended selection type, so a live pass can confirm type 8 and type 16.

## Names beyond nameplate range

Leave `UnitNameFriendlyPlayerName` alone.

Past nameplate range the client does not create a plate. It draws the 3D world name, which is not a frame, so Hide has nothing to suppress for one category. The only switch is that global CVar, and turning it off removes the far name for every friendly player, including categories whose Hide is off. `nameplateMaxDistance` does not take effect when an addon sets it, so plates cannot be pushed out to cover that gap. Forever’s vertical-distance CVars only limit plates above and below the player.

A category with Hide checked still shows the engine name once that player leaves nameplate range.

## Work order

1. Add `CATEGORIES` and point `DefaultColor`, `PruneDB`, `CategoryColor`, `StoreColor`, `StoreHide`, and the hide reader at it. Keep the current party pink, other grey, and other-hide default.
2. Rewrite `Classify` in the order in Classification. Delete the `UnitInParty` party match.
3. Teach `ColorForKind`, `Paint`, `LockHidden`, and the plate `OnUpdate` to color or hide whichever key won.
4. Rebuild the options page as six stacked groups.
5. Register the guild, friend, and recent-ally events and extend the `/powerplate` log.
6. Update the TOC Notes line to mention the six categories.

## Test plan

- The AddOns page shows six separated groups, in order: Party, Raid, Guild, Friends, Recent Allies, Other Players. Each has a color control and a Hide checkbox. Other starts checked. The other five start unchecked.
- A five-person party is pink. A guildmate nearby is green. A friend nearby is amber. A stranger is grey or hidden. You and NPCs are unchanged.
- Hide on Party hides party plates only. Those people stay hidden while they remain in the party. Unchecking it brings the pink plates back.
- In a raid, your subgroup stays pink. Other raid members are blue, including guildmates and friends. After leaving the raid, guildmates turn green and friends turn amber.
- A friend who is also a recent ally stays amber. Someone you just grouped with, outside the raid, guild, and friend list, shows the cyan Recent Allies color once the default plate would.
- Hide on Other hides strangers while guild, friend, raid, and recent plates stay visible. Hide on Friends hides friend plates and leaves party plates shown.
- `/powerplate` during combat still prints a category for party, raid, guild, friend, and recent plates, and leaves a secret unit as unknown.
- Walk a hidden player past nameplate range. The 3D name still appears. That is the engine name, and this change leaves it in place.
