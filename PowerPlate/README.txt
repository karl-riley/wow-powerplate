Power Plate
===========

A World of Warcraft Forever addon that colors player nameplates by
relationship: Party, Raid, Guild, Friends, Recent Allies, and Other Players.
Each category has its own color and can also be hidden.


Install
-------

Option A - link this folder into WoW (recommended, updates automatically)

  1. Keep this PowerPlate folder somewhere permanent, such as OneDrive.
     In OneDrive, right-click it and choose "Always keep on this device".
  2. Double-click install-onedrive.cmd and approve the administrator prompt.
     It creates a link named PowerPlate in:
       World of Warcraft\_forever_\Interface\AddOns
  3. Start the game, or type /reload if it is already running.

Option B - copy the folder

  1. Copy this whole PowerPlate folder into:
       World of Warcraft\_forever_\Interface\AddOns
  2. Start the game, or type /reload if it is already running.

If WoW is installed somewhere other than Program Files (x86), Program Files,
or C:\World of Warcraft, use Option B.


Use
---

  - Enable Power Plate in the AddOns list at character select.
  - Turn on friendly player nameplates in the game's nameplate settings.
  - Open Escape > Options > AddOns > Power Plate to set each category's
    color and Hide option.
  - Debug (bottom of that page) prints Power Plate messages in chat.
    It is off by default. /powerplate prints a status dump when Debug is on.
  - /powerplate max=X sets the max nameplate distance in yards (1 to 1000).
    /powerplate max shows the current value, and /powerplate max=reset
    restores the game default. The value is saved and re-applied at login.
    The game may clamp it, so the command reports what it actually reads back.
    /pp works as a shortcut for /powerplate.
