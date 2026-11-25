# Razer/FxSound Audio Switch

A lightweight Windows PowerShell + C# COM/Win32 interop utility that automatically switches the default Windows playback device between **Razer 7.1 Surround Sound** and **FxSound Audio Enhancer** based on Razer window state.

## How it works

- **Open Razer 7.1 Surround Sound:** Switches the Windows default playback device to Razer 7.1 and pins FxSound's downstream output (`user_selected_playback`) to your physical headset/DAC to avoid an audio feedback loop.
- **Minimize (`-`):** Hides Razer to its existing tray icon while keeping 7.1 surround active.
- **Close (`X`):** Exits the Razer application process (`rzappengine.exe`), restores **FxSound** as the Windows default playback device, and unpins FxSound's output selection.
- **Non-intrusive:** Only switches on Razer open/exit transitions, preserves your Windows communications default, and requires no administrator privileges or modified application binaries.

## Setup on a new PC

1. Copy `config.example.json` to `config.json`.
2. List your active Windows audio endpoint IDs from PowerShell to fill in `SurroundId`, `FxId`, and `PhysicalId`:
   ```powershell
   Add-Type -Path .\AudioInterop.cs
   [RazerFx.Audio]::List() | Format-Table Name, Id -AutoSize
   ```
3. Verify `FxPath` and `RazerPath` in `config.json` match your local install paths.
4. Ensure Razer 7.1 Surround Sound's saved output is set to **FxSound Audio Enhancer**.
5. Start the watcher manually (`powershell -ExecutionPolicy Bypass -File .\Watch-Audio.ps1`) or hidden via `wscript.exe .\Start-Hidden.vbs`.
6. To revert, run `Uninstall.ps1` (stops the watcher, removes the per-user `Run` startup entry if added, and restores saved FxSound registry/settings backups from `%LOCALAPPDATA%\RazerFxAudioSwitch\backup`).

## Tests & validation

Run the unit checks for the state-machine and window-decision logic:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Test-AudioSwitch.ps1
powershell -ExecutionPolicy Bypass -File .\tests\Test-WindowBehavior.ps1
```

- **Unit checks:** 16/16 checks (8 audio mode checks + 8 window state checks) pass.
- **Live switching:** Verified live on Windows 11 (Razer open -> surround, minimize -> tray while keeping surround, restore from tray, `X` -> exit Razer and restore FxSound, communications default unchanged).
- **Known limits:** Automatic sign-in persistence after a full Windows reboot was not verified end-to-end.

## License

MIT - see [LICENSE](LICENSE).
