# Publish Checklist

Repository:

```text
https://github.com/205547125/Claude-code-
```

Release tag:

```text
v1.0.0
```

Release assets:

```text
Git-2.53.0.2-64-bit.exe
CC-Switch-v3.13.0-Windows.msi.zip
```

Main user command:

```powershell
irm https://raw.githubusercontent.com/205547125/Claude-code-/main/install.ps1 | iex
```

Users must run Windows PowerShell as Administrator.

Post-install verification:

```powershell
git --version
claude --version
cc --version
```

Support note:

Ask users for screenshots of terminal errors only. Do not ask users to send API
keys. API keys should be configured locally in CC-Switch.
