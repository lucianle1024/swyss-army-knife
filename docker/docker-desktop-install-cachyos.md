# Installing Docker Desktop on CachyOS (with Pass & GPG Setup)

A complete, step-by-step guide to installing Docker Desktop on CachyOS (Arch-based), verifying KVM virtualization, and properly configuring the `pass` credential store so Docker Hub login works smoothly.

## 1. Verify Hardware Virtualization & KVM

Docker Desktop on Linux runs the Docker daemon inside a lightweight QEMU/KVM virtual machine.

### Step 1.1: Verify KVM Kernel Modules

Run:

```bash
lsmod | grep kvm
```

You should see either `kvm_intel` (for Intel processors) or `kvm_amd` (for AMD processors) listed alongside `kvm`.

If the modules are not loaded:

```bash
# Intel
sudo modprobe kvm_intel

# AMD
sudo modprobe kvm_amd
```

### Step 1.2: Check Permissions on `/dev/kvm`

Ensure the virtualization device node exists:

```bash
ls -l /dev/kvm
```

Add your current user to the `kvm` group:

```bash
sudo usermod -aG kvm $USER
```

> **Note:** Log out and log back in (or run `newgrp kvm`) to refresh your group permissions in your current terminal session.

---

## 2. Install Dependencies and Docker Desktop

CachyOS includes AUR helpers such as `paru` and `yay`.

### Step 2.1: Install Base Dependencies via Pacman

Install QEMU (needed for the virtualization layer) and `pass`:

```bash
sudo pacman -S --needed qemu-desktop pass
```

### Step 2.2: Install the Docker Credential Helper (AUR)

Install `docker-credential-pass-bin` from the AUR using `paru` (or `yay`):

```bash
paru -S --needed docker-credential-pass-bin
# or: yay -S --needed docker-credential-pass-bin
```

Verify that the binary installed successfully:

```bash
which docker-credential-pass
```

*Expected output: `/usr/bin/docker-credential-pass`*

### Step 2.3: Install Docker Desktop Itself (AUR)

Now install the main Docker Desktop package:

```bash
paru -S --needed docker-desktop
# or: yay -S --needed docker-desktop
```

---

## 3. Set Up GPG and Initialize `pass`

Docker Desktop on Linux requires `pass` (the standard Unix password manager) backed by a GPG key to store authentication tokens. If this step is skipped, the **Sign In** button will fail silently.

### Step 3.1: Generate a GPG Key

```bash
gpg --generate-key
```

* **Real name:** You can use your username, a nickname, or a placeholder (e.g., `Docker User`). Real names are not required.
* **Email address:** Any local or real address (e.g., `docker@localhost`).
* **Passphrase:** Enter a passphrase or numeric PIN you can remember (numbers only are completely fine).

### Step 3.2: Retrieve Your GPG Key ID

List your secret keys:

```bash
gpg --list-secret-keys --keyid-format LONG
```

Locate the `sec` line. The key ID is the string directly after the slash (`/`):

```text
sec   ed25519/3AA5C34371567BD2 2026-09-30 [SC]
uid                 [ultimate] Docker User <docker@localhost>
```

In this example, the Key ID is `3AA5C34371567BD2`.

### Step 3.3: Initialize `pass`

Run:

```bash
pass init <YOUR_KEY_ID>
```

*(Replace `<YOUR_KEY_ID>` with your actual key ID from the previous step).*

### Step 3.4: Configure Docker to Use `pass`

Ensure Docker's CLI config points to the `pass` credential store:

```bash
mkdir -p ~/.docker
echo '{"credsStore": "pass"}' > ~/.docker/config.json
```

---

## 4. Launch and Enable Docker Desktop

### Step 4.1: Start the Docker Desktop Service

Launch the user systemd service:

```bash
systemctl --user start docker-desktop
```

To enable it to start automatically on system login:

```bash
systemctl --user enable docker-desktop
```

Alternatively, open your desktop application menu (KDE/GNOME) and search for **Docker Desktop**.

### Step 4.2: Verify the Docker Context

Check that your Docker CLI is targeting Docker Desktop's VM:

```bash
docker context ls
```

The active target should have an asterisk (`*`) next to `desktop-linux`. If not, switch contexts:

```bash
docker context use desktop-linux
```

---

## 5. Log in to Docker Hub

1. Open **Docker Desktop**.
2. Click **Sign in** in the top-right corner.
3. Your default browser will open to Docker Hub for authentication.
4. Once you approve the prompt, Docker Desktop will sign you in automatically.

### Alternative CLI Login:

If browser redirection ever has issues, log in directly via the terminal:

```bash
docker login
```

Enter your Docker ID and Personal Access Token / password. Docker Desktop will immediately pick up the session.

---

## Useful Reference Commands

| Task | Command |
| :--- | :--- |
| **Check key ID used by `pass`** | `cat ~/.password-store/.gpg-id` |
| **List existing GPG secret keys** | `gpg --list-secret-keys --keyid-format LONG` |
| **Restart Docker Desktop service** | `systemctl --user restart docker-desktop` |
| **Stop Docker Desktop service** | `systemctl --user stop docker-desktop` |
| **Inspect running containers** | `docker ps` |