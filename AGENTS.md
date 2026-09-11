# keyboardio2mqtt

## What this is

A macOS-only headless Ruby daemon that connects a Keyboardio Model 100 keyboard to Home Assistant over MQTT, exposing its illuminated keys as a single dimmable, colour-changing light called the availability light, so a person can show colleagues via Home Assistant automations whether they're free, in a meeting, or away.

## Domain

- Keyboard: one physical unit, identified by its USB serial number (identity), with a name (from config, or the default "Keyboardio Model 100") and an AvailabilityLight.
- AvailabilityLight: the single light on the keyboard; holds colour, brightness and on/off state, and remembers the last command it was asked for.
- KeyboardFinder: the only place that knows how to find a keyboard on this machine — reads the USB bus with `ioreg`, matches Keyboardio's vendor/product IDs, and maps a serial number to a `/dev/cu.usbmodem*` port via FocusPort.
- Daemon: on each round, finds attached keyboards, announces new ones to Home Assistant, restores the last-remembered light state, listens for new commands, and reports keyboards that disappear as offline; one gone for more than 48 hours is forgotten entirely and removed from Home Assistant.
- RememberedState: persists the last light state per keyboard to a JSON file on disk (state_file), so a restart shows the last-known colour rather than resetting.
- Broker: the MQTT connection — announces devices, publishes state/availability, and dispatches incoming commands.
- Configuration: read from a YAML file (see `config/keyboardio2mqtt.example.yml`) — holds broker connection details, log level, state file path and keyboard name overrides; never holds a raw password.
- Secret: wraps a config value that may be a literal or an `op://` 1Password reference, resolved at startup via the `op` CLI (1Password must already be unlocked).
- Two things are deliberately left to the firmware, not this daemon: the colour fade (~2 seconds to reach a new colour), and the power cap that silently dims an overly bright white.
- Brightness is dimmed by darkening the colour sent over the wire, never by sending the keyboard's own brightness command, because that command writes to permanent flash memory and would wear it out under frequent updates.

## Commands

- Setup: `rv install && bundle install`, then copy `config/keyboardio2mqtt.example.yml` to `~/.config/keyboardio2mqtt/config.yml` and edit it.
- Run: `bin/keyboardio2mqtt --config ~/.config/keyboardio2mqtt/config.yml` (needs 1Password unlocked if secrets use `op://` references).
- Test: `bundle exec rake test` — no real keyboard or broker needed; tests assert against stand-ins under `test/support/`.
- Lint: `bundle exec rubocop`.
- Audit: `bundle exec bundler-audit check --update`.

## Gotchas

- macOS only: KeyboardFinder shells out to `ioreg`, so nothing here runs, or can be tested for real, on another OS.
- No Brakeman and no locale files, on purpose — this is a headless daemon with no web surface and no user-facing strings to translate.
- The keyboard can't be read back: everything Home Assistant shows is the last command sent, never a live reading from the keyboard.
- Firmware says "color", Ruby says "colour" — deliberate, and the two meet on the one line that builds the command sent to the keyboard.
- `.rubocop.yml` inherits `rubocop-rails-omakase`, not the usual personal-project `rubocop-eirvandelden` gem — a deliberate deviation, not something to "fix".
