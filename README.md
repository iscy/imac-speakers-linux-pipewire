# iMac Speakers on Linux (PipeWire)

Get the internal speakers of a 2015 iMac working correctly on Linux (Fedora 44, but any
PipeWire-based distro works) by routing stereo audio to all four speaker channels.

## The problem

The 2015 iMac's internal audio is driven by an **CS4208** codec (ALSA card `HDA Intel PCH`).
The codec exposes **four physical output channels** — `aux0`, `aux1`, `aux2`, `aux3` — but
the stock Linux channel mapping is wrong:

- The "front" channels are not actually the front speakers.
- A stereo app only drives two of the four speakers, and often the wrong pair.
- The `analog-surround-40` profile mislabels the channels as
  `rear-left, rear-right, front-left, front-right`, and there is no stock profile that
  maps a stereo stream to the four physical speakers the way the iMac expects.

## What this does

This repository provides a **PipeWire filter-chain** configuration that creates a virtual
sink named **`iMac`**. It takes a normal 2-channel stereo stream and fans each channel
out to two physical speakers:

```
            ┌────────────┐
  Left  ──► │    copy    ├──────────► aux0  (speaker 1)
            └────────────┘
                       └──────────► aux1  (speaker 2)

            ┌────────────┐
  Right ──► │    copy    ├──────────► aux2  (speaker 3)
            └────────────┘
                       └──────────► aux3  (speaker 4)
```

No external plugins are required — the graph is built entirely from PipeWire's
**built-in `copy` nodes** (a `copy` node is a 1-in/1-out passthrough whose output can
be linked to any number of inputs, i.e. a "tee"). The resulting `iMac` sink behaves
like any normal stereo sink: pick it in your sound picker, or route a specific app to
it.

## Requirements

- A Linux system using **PipeWire** (Fedora 41+, Arch, recent Debian/Ubuntu, etc.)
- The iMac's audio card set to the **4-channel "pro-audio" profile** (the profile that
  exposes `aux0`–`aux3`). In `pactl list short sinks` this is the sink ending in
  `pro-output-0`.
- The `filter-chain` PipeWire service (shipped with PipeWire on Fedora; see below)

## Installation

### Quick (make)

```sh
git clone https://github.com/iscy/imac-speakers-linux-pipewire
cd imac-speakers-linux-pipewire
make install     # installs the config and enables/starts the filter-chain service
make status      # show service state and sink presence
make verify      # fail unless the iMac sink is present
```

`make install` installs `filter-chain.conf.d/imac.conf` to
`~/.config/pipewire/filter-chain.conf.d/` and then runs
`systemctl --user enable --now filter-chain`. If the `filter-chain.service` unit
isn't present on your system, it prints the manual fallback
(`pipewire -c filter-chain.conf`).

### Manual

```sh
git clone https://github.com/iscy/imac-speakers-linux-pipewire
cd imac-speakers-linux-pipewire
install -Dm644 filter-chain.conf.d/imac.conf \
    ~/.config/pipewire/filter-chain.conf.d/imac.conf
```

### Start the filter-chain service

The filter-chain configuration does **not** run inside the main `pipewire` service —
it runs as a separate client process (`pipewire -c filter-chain.conf`) with its own
systemd user unit:

```sh
systemctl --user enable --now filter-chain
systemctl --user status filter-chain
```

> If `enable` reports the unit is missing, start it manually to test:
> `pipewire -c filter-chain.conf` (leave the terminal open). If the sink appears,
> create the unit or use `systemd-run --user --unit=filter-chain pipewire -c filter-chain.conf`.

### Verify

```sh
pactl list short sinks | grep iMac
```

You should see a sink named `iMac`. Select it as the default output (or per-app) and
play a stereo track — all four speakers should play, with the left channel driving
`aux0`+`aux1` and the right channel driving `aux2`+`aux3`.

## Usage

- **Default for everything:** select `iMac` as the default output in your sound settings.
- **Per app:** route a specific application to the `iMac` sink (e.g. via `wpctl`,
  `pavucontrol`, or the desktop sound picker).
- The original 4-channel `pro-output-0` sink remains available for apps that want to
  address individual channels.

## How it works

`filter-chain.conf.d/imac.conf` loads `libpipewire-module-filter-chain`, which builds a
virtual sink/source pair around a filter graph:

- **Capture side (the sink):** presents a 2-channel `[FL FR]` device to applications.
- **Graph:** two `copy` nodes tee the two input channels; `links` fan each tee out to
  two output `copy` nodes — one per physical speaker.
- **Playback side:** a 4-channel `[FL RL FR RR]` stream that WirePlumber auto-links to
  the physical 4-channel ALSA device.

Because the graph only uses built-in nodes, there is nothing to compile or install —
the config file *is* the whole solution.

## Customizing

The mapping lives in the `links` section of the config. If your iMac's physical channel
order differs (a side plays on the wrong speaker), swap the corresponding `outputs`
entries and `audio.position` in `playback.props`. For example, to send the left channel
to `aux0`+`aux2` instead, re-point the `copyL` links accordingly.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `iMac` sink doesn't appear | The `filter-chain` service isn't running. `systemctl --user status filter-chain`; check `journalctl --user -u filter-chain` for config parse errors. |
| Sink appears but is silent | The card is not in the 4-channel pro-audio profile, so the playback stream has no device to link to. Set the profile and restart `pipewire`. Check the link with `pw-top`. |
| A side plays on the wrong speaker | The physical channel order differs from the config. Swap the `audio.position` / `outputs` entries as described in *Customizing*. |
| Sink disappears after reboot | `filter-chain` service not enabled: `systemctl --user enable filter-chain`. |

## Uninstall

```sh
rm ~/.config/pipewire/filter-chain.conf.d/imac.conf
systemctl --user disable --now filter-chain   # only if you don't use other filter chains
```

## License

[MIT](LICENSE)
