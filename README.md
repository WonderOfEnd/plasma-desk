# desk — workspace themes for KDE Plasma 6

[Русская версия](README.ru.md)

`desk` saves your whole Plasma desktop as a named theme and switches between themes in one
click: panels and their widgets, desktop widgets, wallpapers (pictures, videos, any wallpaper
plugin) on every monitor, color scheme, Plasma style, icons, cursor, fonts, window
decorations, Kvantum theme, Alt+Tab switcher, lock screen and more.

Build a "Windows 11" desktop, an anime desktop with a video wallpaper and a minimal work
desktop, save each one, and flip between them from a panel widget.

## Why not Konsave or a global theme?

- **Global themes** (Look and Feel packages) only cover part of the look, and applying one
  with "desktop layout" resets your panels to the theme author's layout. Your own widgets and
  their settings are lost.
- **Konsave** copies config files while `plasmashell` is running. Plasma rewrites its files when
  it exits, so panels and widgets often come back wrong or not at all.

`desk` stops the Plasma shell, writes the files, starts it again and notifies running apps
and KWin, so the switch takes effect at once without logging out. It also:

- **merges files instead of replacing them.** From `kdeglobals` or `kwinrc` it takes only the
  look-related groups and keys. Your shortcuts, mouse, monitor, tiling, locale and app
  settings are never touched.
- **stores wallpapers with the theme.** Each referenced picture or video is copied once
  (deduplicated by content) into `~/.local/share/desk-themes/.assets/`, so a theme keeps
  working after you move or delete the original file. Unused copies are cleaned up.
- **keeps backups.** Every switch first backs up the current state (the last 5 are kept).
  `desk restore` brings it back.
- **detects unsaved changes.** If you changed the desktop after applying a theme, the picker
  offers to save those changes before switching away.
- **warns about missing pieces.** It lists widgets, wallpaper plugins, icon themes, cursors,
  color schemes or global themes a theme needs that aren't installed.

## What a theme contains

| Saved | Files |
|---|---|
| Panels, desktop widgets, wallpapers per monitor | `plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc` |
| Plasma style, splash screen | `plasmarc`, `ksplashrc` |
| Global theme defaults layer | `~/.config/kdedefaults/` |
| Colors, accent, fonts, icons, widget style | parts of `kdeglobals` |
| Window decoration, KWin effects, Alt+Tab look | parts of `kwinrc`, `breezerc`, `auroraerc`, Aurorae theme rc, `klassyrc`, `lightlyrc`, `darklyrc` |
| Kvantum theme selection | `Kvantum/kvantum.kvconfig` |
| Cursor theme and size | part of `kcminputrc` |
| Lock screen wallpaper and look | `[Greeter*]` of `kscreenlockerrc`, user copy of the desktop shell (custom lock screen QML) |
| Keyboard layout labels in the tray | `DisplayNames` in `kxkbrc` |
| Default file manager | `inode/directory` in `mimeapps.list` |
| KRunner position (top or centered) | `FreeFloating` in `krunnerrc` |
| Which monitor holds the main desktop | `main-output` in the theme directory |

Not saved, on purpose: shortcuts, mouse and touchpad, the display layout, tiling, locale, power
settings, and the settings of your applications. The themes themselves (icon packs, Plasma
styles, widgets) are referenced by name, not copied: install them as usual.

## Install

Requirements: KDE Plasma 6, Python 3.8+, `kdialog` (picker window), `ffmpeg` (optional,
previews for the panel widget), `kscreen-doctor` (comes with KScreen; for the monitor
commands).

```sh
git clone https://github.com/WonderOfEnd/plasma-desk
cd plasma-desk
./install.sh
```

This puts `desk` into `~/.local/bin`, installs the **Desktop Themes** panel widget, and adds a
"Desktop Themes" menu entry. Run `./install.sh --uninstall` to remove it. Your themes stay in
`~/.local/share/desk-themes`.

## Use

1. Set up your desktop the way you like it, then save it:
   `desk save "Work"` (or open **Desktop Themes** from the menu).
2. Build another one. `desk clean` resets to the stock Plasma layout to start from scratch
   (the current state is backed up first). Then `desk save "Anime"`.
3. Switch with `desk apply "Work"`, from the menu window, or with the panel widget.

```
desk                  picker window
desk list             list themes (* marks the applied one)
desk save NAME        save the current desktop as a theme (or overwrite it)
desk apply NAME       switch to a theme
desk rm NAME          delete a theme
desk mv OLD NEW       rename a theme
desk clean            reset to the stock Plasma layout to build a new theme
desk restore          go back to the state before the last switch
desk json             themes as JSON (used by the panel widget)
desk preview [NAME…]  regenerate preview images
desk swap             move the main desktop to the other monitor
desk screens one [OUTPUT]   leave only one monitor on (the main one by default)
desk screens all      turn the other monitors back on, as they were
```

### Several monitors

Plasma puts desktops and panels on screens in the order of output priority: its screen 0
is always the primary monitor. `desk` builds on that: the main desktop of a theme (the
wallpaper and widgets you care about most) lives on screen 0, and the theme remembers which
monitor that is (`main-output`, by connector name such as `DP-3`).

- `desk swap` makes the other monitor the main one. Plasma moves the desktops and panels at
  once, without a restart, and the current theme remembers the choice. Applying a theme
  makes its main monitor primary again.
- When only one monitor is left on, it is screen 0 and shows the main desktop, whichever
  monitor it is. When the others come back, everything returns to its place.
- `desk screens one [OUTPUT]` saves the display layout and turns off all monitors but one.
  `desk screens all` turns them back on with their old positions and modes, and makes the
  theme's main monitor primary.

The panel widget has buttons for all three. One use: turn a monitor off automatically when
you stream the desktop with Sunshine, with a prep command in `sunshine.conf`:

```ini
global_prep_cmd = [{"do":"/home/you/.local/bin/desk screens one DP-3","undo":"","elevated":false}]
```

### Panel widget

Add **Desktop Themes** to a panel. Clicking it shows a card for each theme. A card shows a
preview made from the theme's wallpaper (a video frame for video wallpapers) and the theme's
icon. Click a card to switch. The widget also shows when the applied theme has unsaved
changes and lets you save them. The ⚙ button opens the full picker (new, rename, delete).
With two monitors on, the header has buttons to swap screens and to leave only the main
monitor; with one turned off, a "Turn on all monitors" button.

To give a theme its own icon, put an `icon.svg` (white, 24×24 works best) into
`~/.local/share/desk-themes/<name>/`. To use your own preview, replace `preview.jpg` there.
Both are kept when the theme is saved again.

Add the widget to the panel of **every** theme you want to switch from: it's part of the
panel layout, like any other widget.

### Settings

Optional, in `~/.config/deskrc`:

```ini
[General]
Language=ru        # en or ru; by default it follows your locale
PreviewScreen=0    # Plasma screen number whose wallpaper becomes the preview
```

## How it works

A theme is a directory `~/.local/share/desk-themes/<name>/` with copies of whole files
(`config/…`), the look-related part of shared files (`config/<file>.part`), and lists of files
the theme did not have (`.absent`, `.absent-data`): those are removed on apply, so files left
behind by another theme can't leak into this one.

Applying a theme:

1. backs up the current state to `.backups/`,
2. stops `plasma-plasmashell.service` (or `plasmashell`),
3. writes whole files, merges partial ones into your live files,
4. starts the shell again,
5. applies the color scheme, cursor and icons, and sends the KConfig/KGlobalSettings change
   signals so running apps, GTK apps (through kde-gtk-config) and KWin pick up the change.

## Notes

- A widget that applies a theme must not run `desk` as its own child process: the child
  dies when the shell stops. The bundled widget runs it via `systemd-run --user`.
- Video and web wallpapers come from third-party wallpaper plugins. `desk` saves their
  settings and files like any other wallpaper.
- Things outside the list above (for example sounds or the SDDM login screen) are not part
  of a theme yet. Adding a file is a one-line change in `WHOLE` or `PARTIAL` at the top of
  `desk`.

## License

GPL-3.0. See [LICENSE](LICENSE).
