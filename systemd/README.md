# Example SystemD units

Services & timers for running some of the scripts automatically.

## How to use

For example, on Debian based systems:

1. Customize to meet your requirements.
2. Copy to `/etc/systemd/system/`.
3. Reload with `sudo systemctl daemon-reload`.
4. Enable unit `sydo systemctl enable <unit-name>.timer`.
5. Start unit `sydo systemctl enable <unit-name>.timer`.

For units with timers, only the timer should be enabled & started, as it runs the `.service` unit.
