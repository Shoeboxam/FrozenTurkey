# Iron Turkey

A small macOS companion utility for [Cold Turkey](https://getcoldturkey.com/).

Cold Turkey is a useful blocking app, but its internal configuration can be
easier to change than many users expect. Iron Turkey adds a guard
that helps Cold Turkey continue enforcing the blocking setup you chose.

## Usage

Iron Turkey has two modes: **Normal Mode** and **Edit Mode**. 
Launching Iron Turkey toggles between the two modes. 
Each mode change requires administrator approval.

In Normal Mode, Iron Turkey monitors your Cold Turkey configuration,
only keeping policy changes that are more restrictive. Statistics databases are
kept with an append-or-increment-only rule over the active policy window.

When entering Edit Mode, Iron Turkey opens Cold Turkey. 
While in Edit Mode, the guard is disabled so you can adjust your configuration normally.

When returning to Normal Mode, Iron Turkey asks whether to keep or discard your changes.
Iron Turkey automatically exits Edit Mode at **5:00 AM**, discarding any unconfirmed changes.


## Install

```bash
sudo ./install.sh
```

This installs:

- `/Applications/Iron Turkey Locker.app`
- `/Library/Application Support/IronTurkeyLocker`
- `/Library/LaunchDaemons/com.ironturkey.locker.guard.plist`
- `/Library/LaunchDaemons/com.ironturkey.locker.restore.plist`

If no baseline exists yet, the installer snapshots the current Cold Turkey local state.

## Upgrade

```bash
sudo ./install.sh
```

## Uninstall

```bash
sudo ./uninstall.sh
```

## Development

Rebuild the app bundle locally with:

```bash
./build_app.sh
```

The generated app is written to `build/Iron Turkey Locker.app`.
