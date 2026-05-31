# Claude Code Windows One-Click Installer

This repository provides a Windows-first one-click installer for Claude Code.
It installs Claude Code for the current Windows user, updates user PATH, verifies
the install, and then shows a local-only setup guide for cc-switch or third-party
model channels.

## One-Line Install Command

Recommended GitHub Raw entry:

```powershell
irm https://raw.githubusercontent.com/205547125/Claude-code-/main/install.ps1 | iex
```

If `raw.githubusercontent.com` is not reachable on a mainland China network, try
the CDN entry:

```powershell
irm https://cdn.jsdelivr.net/gh/205547125/Claude-code-@main/install.ps1 | iex
```

Install Claude Code only and skip the post-install menu:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/205547125/Claude-code-/main/install.ps1) } -SkipMenu"
```

## What The Script Does

- Checks Windows, 64-bit OS, 64-bit PowerShell, and PowerShell version.
- Enables TLS 1.2.
- Downloads Claude Code from Anthropic's official GCS release endpoint.
- Reads `latest` and `manifest.json`, then selects the correct Windows binary.
- Verifies file size and SHA256 checksum.
- Installs to the current user's profile:
  - `%USERPROFILE%\.local\share\claude\versions`
  - `%USERPROFILE%\.local\bin\claude.exe`
  - `%USERPROFILE%\.local\bin\cc.cmd`
- Backs up and updates `%USERPROFILE%\.claude.json`.
- Adds `%USERPROFILE%\.local\bin` to user PATH and the current session PATH.
- Runs `claude --version` to verify the installation.
- Provides both commands: `claude` and `cc`.
- Shows an optional local-only guide for cc-switch and third-party providers.

## Security Boundaries

- The script does not collect, upload, print, or store user API keys.
- Third-party provider setup is only a local guide. Users should enter API keys
  only in their local cc-switch app or local config.
- The script does not bypass network restrictions. If the official Claude Code
  release endpoint is unreachable, it prints a clear error.
- The script does not require administrator privileges.

## Mainland China Network Notes

The one-line command has two network dependencies:

1. Script entry:
   - `raw.githubusercontent.com`, or
   - `cdn.jsdelivr.net`
2. Claude Code binary download:
   - `storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases`

The CDN entry may improve access to the script itself, but the binary still comes
from Anthropic's official Google Storage release endpoint. Some mainland China
networks may fail there. In that case, users need a working network/proxy and
should rerun the same command.

## Common Troubleshooting

### 32-bit PowerShell

If the script says `You are running 32-bit PowerShell on 64-bit Windows`, open the
normal Windows PowerShell from the Start menu, not `Windows PowerShell (x86)`.

### Network failure

The script needs access to:

```text
https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
```

If this fails, ask the user to screenshot the red error message from the terminal.

### Install succeeds but `claude` is not found

Close and reopen PowerShell, then run:

```powershell
claude --version
```

You can also run the shortcut command:

```powershell
cc --version
```

## Test Matrix

- Windows 11 x64 + Windows PowerShell 5.1.
- Windows 11 x64 + PowerShell 7.
- Windows ARM64.
- Normal user permissions, no administrator rights.
- Repeated installer runs.
- Existing `.claude.json`.
- Network failure, download failure, and SHA256 mismatch.
