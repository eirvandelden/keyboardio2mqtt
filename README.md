# keyboardio2mqtt

Makes a Keyboardio Model 100 available to Home Assistant over MQTT, so the keys can show whether
you are free.

Run it on the computer the keyboard is plugged into. It finds the keyboard, announces it to your
MQTT broker as a single light, and turns Home Assistant's colour and brightness commands into
commands the keyboard's firmware understands.

## Working on it

```
bundle exec rake test        # the whole suite; no keyboard and no broker needed
bundle exec rubocop
bundle exec bundler-audit check --update
```

Tests never touch a real keyboard and never talk to a real broker. They assert the command lines
we send to a keyboard and the payloads we publish to a broker, using stand-ins for both.

Two departures from the usual personal-project setup, both on purpose:

- **No Brakeman.** It scans Rails applications; this is a headless daemon with no web surface.
- **No locale files.** There is no user interface to translate. The only name anyone reads is the
  friendly name they write in their own configuration, and Home Assistant translates its own
  interface.

Work happens in a worktree under `.worktrees/`, never in the main checkout.
