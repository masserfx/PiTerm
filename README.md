# PiTerm

Open-source iOS terminal for running Claude Code CLI on Raspberry Pi via SSH.

## Features

- **SSH Terminal** — Full VT100/xterm terminal emulator powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- **SwiftNIO SSH** — Pure Swift SSH client using [swift-nio-ssh](https://github.com/apple/swift-nio-ssh)
- **Tailscale Aware** — Automatic VPN detection and `.ts.net` hostname support
- **Claude CLI Integration** — Quick actions for tmux session management and Claude commands
- **Extra Keys Bar** — Esc, Tab, Ctrl, Alt, arrows, and special characters
- **Secure** — SSH keys and passwords stored in iOS Keychain
- **SwiftData** — Native host management with iCloud-ready persistence

## Use Case

```
iPhone/iPad → Tailscale VPN → SSH → Raspberry Pi → tmux → Claude CLI → GitHub repos
```

## Requirements

- iOS 17.0+
- Xcode 15.4+
- Raspberry Pi with SSH, tmux, and Claude CLI installed
- [Tailscale](https://tailscale.com) for remote access (optional but recommended)

## Building

1. Open `PiTerm/PiTerm.xcodeproj` in Xcode
2. Wait for SPM dependencies to resolve
3. Select your target device/simulator
4. Build and run (Cmd+R)

## Raspberry Pi Setup

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Install Node.js 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Install Claude CLI
npm install -g @anthropic-ai/claude-code

# Install tmux
sudo apt install tmux

# Verify
tailscale status && claude --version && tmux -V
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  iOS App (SwiftUI)                          │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ │
│  │HostList  │ │ Terminal  │ │ Claude      │ │
│  │View      │ │ View      │ │ Dashboard   │ │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘ │
│       │             │              │         │
│  ┌────┴─────────────┴──────────────┴──────┐ │
│  │        SSHSession (actor)              │ │
│  │  SwiftNIO SSH ↔ SwiftTerm TerminalView │ │
│  └────────────────┬───────────────────────┘ │
└───────────────────┼─────────────────────────┘
                    │ SSH over Tailscale VPN
┌───────────────────┼─────────────────────────┐
│  Raspberry Pi     │                         │
│  ┌────────────────┴───────────────────────┐ │
│  │  tmux → Claude CLI → GitHub/Obsidian   │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Tech Stack

| Component | Choice |
|---|---|
| Terminal | SwiftTerm (MIT) |
| SSH | swift-nio-ssh (Apache 2.0) |
| UI | SwiftUI + UIViewRepresentable |
| Architecture | MVVM + @Observable |
| Persistence | SwiftData |
| Keychain | Security framework |

## License

MIT — see [LICENSE](LICENSE)
