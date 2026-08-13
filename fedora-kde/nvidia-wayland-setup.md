# 🐧 Fedora KDE + NVIDIA dGPU

Configure your external monitor to use dGPU on Wayland.

---

## 1. Create NVIDIA environment config

First, create the directory and configuration file:

```bash
mkdir -p ~/.config/environment.d
nano ~/.config/environment.d/nvidia.conf
```

Then paste this content into nano:

```ini
NVIDIA_MCD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
MOZ_DISABLE_RDD_SANDBOX=1
```

Save the file with: `Ctrl+X`, then `Y`, then `Enter`.

---

## 2. Configure plasmarc for Wayland

Edit the Plasma configuration file:

```bash
nano ~/.config/plasmarc
```

Add these lines at the end of the file:

```ini
[General]
Session=plasmawayland
```

Save with: `Ctrl+X`, then `Y`, then `Enter`.

> [!NOTE]
> If your `plasmarc` is empty or only has wallpaper settings, just add these lines at the end.

---

## 3. Reboot your system

Apply the changes by rebooting:

```bash
sudo reboot
```

> [!WARNING]
> Close any unsaved work before rebooting!

---

## 4. Verify NVIDIA is active

After reboot, run these commands to confirm:

```bash
nvidia-smi
```

Then check the renderer:

```bash
glxinfo -B | grep "OpenGL renderer"
```

You should see your NVIDIA GPU name (e.g., `NVIDIA GeForce RTX 4070`).

> [!TIP]
> **✓ Verification:** If you see your GPU name, the setup is working!

---

## 5. Optional: Set NVIDIA to max performance

For maximum GPU utilization, open NVIDIA Settings:

```bash
nvidia-settings
```

Then:
1. Go to **PowerMizer** tab
2. Set "Preferred Mode" to **"Prefer Maximum Performance"**
3. Close the settings

---

> [!IMPORTANT]
> **✓ All done!** Your external monitor should now be using your dGPU on Wayland. Enjoy better performance for gaming and graphics-heavy applications!

> [!NOTE]
> **Troubleshooting:** If your external monitor isn't using the dGPU after these steps, it might be physically connected to your integrated GPU. Check your laptop's BIOS settings or use a USB-C dock that connects to the dGPU.

---
*Fedora KDE NVIDIA Wayland Setup Guide*
