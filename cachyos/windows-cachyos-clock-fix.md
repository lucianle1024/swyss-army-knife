# Fixing the Clock Reset Issue on Windows 11 / CachyOS Dual Boot

## The Problem

On a dual-boot system with Windows 11 and CachyOS (or any Linux distro), the system clock appears to reset or jump every time you switch between operating systems — even with "Set time automatically" enabled in Windows.

This isn't actually a reset. It's a disagreement between Windows and Linux about how the hardware clock (RTC) should be interpreted.

- Your PC has one physical hardware clock (RTC) shared by both operating systems.
- CachyOS, like most Linux distros, writes the hardware clock in **UTC** by default and converts to your local timezone in software.
- Windows, by default, assumes the hardware clock is already in **local time** and does no conversion.

So when you boot CachyOS, it writes the correct UTC time to the RTC. When you then boot into Windows, Windows reads that UTC value and treats it as local time — throwing the displayed clock off by your timezone's UTC offset.

"Set time automatically" doesn't fix this because it only syncs against an internet time server periodically, not instantly on every boot, and if the Windows Time service (`w32time`) isn't running, it won't sync at all.

## The Fix

### 1. Open an elevated terminal
Right-click the Start button and choose **Terminal (Admin)** or **Command Prompt (Admin)**.

### 2. Tell Windows the hardware clock is in UTC
Run as a single line:
```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```
This makes Windows interpret the RTC as UTC, matching how CachyOS writes it, instead of assuming it's already local time.

### 3. Reboot into Windows
Restart so the registry change takes effect.

### 4. Make sure the Windows Time service is running
```
net start w32time
```
If it says the service is disabled, first run:
```
sc config w32time start= demand
```
then run `net start w32time` again.

### 5. Force a resync
```
w32tm /resync /force
```
This pulls the correct time immediately instead of waiting for the next automatic sync.

### 6. Verify
Check the clock in the system tray, or run:
```
w32tm /query /status
```
Reboot into CachyOS and back into Windows a couple of times to confirm the clock no longer jumps.
