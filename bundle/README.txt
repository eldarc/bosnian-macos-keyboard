BOSNIAN macOS KEYBOARD
======================

Bosnian keyboard layouts for macOS, with a BA badge in the menu bar.

This folder contains:

  Bosnian.bundle   the layouts
  README.txt       this file


INSTALL
-------

1. Open the folder  /Library/Keyboard Layouts

   In Finder, press Shift-Command-G, type that path and press Return.

   Note the leading slash: this is the Library folder of the whole Mac, not
   the one inside your home folder.

2. Copy  Bosnian.bundle  into that folder.

   macOS asks for your password, because the folder belongs to the whole Mac
   rather than to one account.

3. Restart your Mac.

   macOS reads the installed keyboard layouts once at the start of a session
   and caches them, so the new layouts stay hidden until it reads them again.
   A restart is the one thing that reliably refreshes every part of the
   system.

4. Open  System Settings > Keyboard > Input Sources > Edit...

   Click the + button, choose "Bosnian" in the list on the left, select the
   layouts you want, and click "Add".

   The two English layouts are listed under "English", not "Bosnian".


WHY THE WHOLE-MAC LIBRARY FOLDER
--------------------------------

The login and lock screens run outside your account, so they can only use
layouts that are installed for the whole Mac. The folder above is read by the
system itself and serves every account, which is what makes the layouts
available on the lock screen. A copy inside your home folder is only ever read
once you are logged in.


AT THE LOGIN SCREEN
-------------------

Right after your Mac starts up, before anyone has logged in, the login screen
still offers only the layouts macOS ships with. The Bosnian layouts are not
there yet, so sign in with the layout you used before.

Once you have logged in, they are loaded for the rest of that session. Lock
your screen and the Bosnian layouts are available there, so this only affects
the very first sign-in after a boot.


THE LAYOUTS
-----------

  Bosnian – QWERTY
      The Bosnian layout, with Y and Z in the QWERTY positions.

  Bosnian – QWERTZ
      The Bosnian layout, with Y and Z swapped, as on a local keyboard.

  Bosnian - International English
      English typing, listed under Bosnian.

  Bosnian - U.S.
      English typing, listed under Bosnian.

The two English layouts carry a line under the letters on the badge, so you
can tell them apart in the menu.


UNINSTALL
---------

Remove  Bosnian.bundle  from  /Library/Keyboard Layouts  and restart. macOS
asks for your password. Removing the layouts in System Settings first keeps
the input menu tidy.


IF SOMETHING DOES NOT SHOW UP
-----------------------------

Restart. macOS caches keyboard layouts and their icons for the whole session,
so a layout you just copied, or an icon you just replaced, will not appear
until the system reads them again.

If a restart is not enough and an old icon is still showing, delete that cache
and restart again:

  rm -f "$(getconf DARWIN_USER_CACHE_DIR)"/com.apple.IntlDataCache.le*


More, including the source and the icon generator:
https://github.com/eldarc/bosnian-macos-keyboard
