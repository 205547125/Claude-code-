# Claude Code One-Click Installer for Windows

Run this in **Windows PowerShell as Administrator**:

```powershell
irm https://raw.githubusercontent.com/205547125/Claude-code-/main/install.ps1 | iex
```

## What It Installs

The script installs these components in order:

1. Git for Windows `Git-2.53.0.2-64-bit.exe`
2. Claude Code by running:
   ```powershell
   irm https://daheiai.com/cc.ps1 | iex
   ```
3. CC-Switch `CC-Switch-v3.13.0-Windows.msi.zip`
4. User PATH entries for:
   - `%USERPROFILE%\.local\bin`
   - `C:\Program Files\Git\cmd`
5. A shortcut command:
   - `%USERPROFILE%\.local\bin\cc.cmd`

After installation, both commands should work:

```powershell
claude --version
cc --version
```

## API Setup

The script opens CC-Switch after installation.

Use CC-Switch to choose your own provider and enter your API key locally.
This installer does **not** read, save, upload, print, or send your API key.

If CC-Switch does not open automatically:

1. Open the Start menu.
2. Search for `CC-Switch`.
3. Add your provider and API key in the CC-Switch UI.

## Network Notes

The script downloads Git and CC-Switch from this repository's GitHub Release
`v1.0.0`.

Claude Code itself is installed through:

```text
https://daheiai.com/cc.ps1
```

That installer may use additional upstream download URLs. If a mainland China
network blocks those URLs, switch network/proxy and rerun the same command.

## Troubleshooting

### Not running as administrator

If the script says administrator PowerShell is required, right-click Windows
PowerShell and choose **Run as administrator**, then rerun the install command.

### Install completes but commands are not found

Close and reopen PowerShell, then run:

```powershell
git --version
claude --version
cc --version
```

### API key safety

Do not send your API key to anyone. Configure it only in CC-Switch on your own
computer.
