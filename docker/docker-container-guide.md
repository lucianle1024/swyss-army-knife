# Docker Migration Guide: Containers to Docker Hub & Multi-Device Setup

This guide walks you through preserving the exact state of existing Docker containers (such as `server` and `client`), uploading them to Docker Hub, and running them on a secondary device.

---

## Prerequisites

1. **Docker / Docker Desktop** installed on both devices.
2. A **Docker Hub account** (e.g., `lucianle1024`).
3. CLI access (PowerShell, Command Prompt, or Bash).

---

## Phase 1: Prepare & Upload (Source Machine)

### 1. Identify Your Containers
Containers can be committed whether they are running or stopped. Check for all containers:

```powershell
docker ps -a
```

Identify the target container names or IDs (e.g., `server`, `client`).

---

### 2. Log in to Docker Hub
Ensure your terminal session is authenticated:

```powershell
docker login
```
* Enter your **Docker Hub username** (not your email).
* Enter your **Password** or **Personal Access Token (PAT)**.

---

### 3. Commit Containers into Tagged Images
A container must be committed into an image before it can be pushed.

> **Naming Rule:** The repository name must be entirely **lowercase** and prefixed with your Docker Hub username:  
> `<username>/<repo_name>:<tag>`

#### For the `server` container:
```powershell
docker commit server lucianle1024/tne30009:server-backup
```

#### For the `client` container:
```powershell
docker commit client lucianle1024/tne30009:client-backup
```

---

### 4. Push Images to Docker Hub
Pushing to a non-existent repository automatically creates it as a public repository under your Docker Hub account.

#### Push the `server` image:
```powershell
docker push lucianle1024/tne30009:server-backup
```

#### Push the `client` image:
```powershell
docker push lucianle1024/tne30009:client-backup
```

**Verification:** You should see layer progress bars followed by a final digest hash line:
```text
server-backup: digest: sha256:... size: 752
client-backup: digest: sha256:... size: 751
```
You can also visit [hub.docker.com](https://hub.docker.com) to view the uploaded tags under the `tne30009` repository.

---

## Phase 2: Pull & Run (Target Machine)

Run these commands on the new device. Docker will automatically pull the missing layers directly from Docker Hub before starting the containers.

### 1. Log In (Required if the repository is private)
```bash
docker login
```
*(If your repository is public, logging in on the target machine is optional).*

---

### 2. Run the Containers

#### Launch the Server Container:
```bash
docker run -it --name server lucianle1024/tne30009:server-backup /bin/bash
```

#### Launch the Client Container:
```bash
docker run -it --name client lucianle1024/tne30009:client-backup /bin/bash
```

* Flags explained:
  * `-it`: Attaches an interactive TTY session (drops you straight into the container's bash prompt).
  * `--name`: Assigns a readable local container name.
  * `/bin/bash`: Executes the bash shell upon startup.

---

## Optional: Connecting Server and Client over a Network

If your client and server need to communicate via hostnames or static IPs on the new device, place them on a custom Docker bridge network:

```bash
# 1. Create a bridge network
docker network create lab-network

# 2. Start the server on that network
docker run -it -d --name server --network lab-network lucianle1024/tne30009:server-backup /bin/bash

# 3. Start the client on the same network
docker run -it --name client --network lab-network lucianle1024/tne30009:client-backup /bin/bash
```

From inside the `client` terminal, you can now reach the server by name:
```bash
ping server
```

---

## Troubleshooting Quick Reference

| Issue | Cause | Fix |
| :--- | :--- | :--- |
| `invalid reference format: repository name must be lowercase` | Uppercase letters used in repository name. | Convert all characters in `<repo_name>` to lowercase (e.g., `tne30009`). |
| `push access denied, repository does not exist or may require authorization` | Not logged in, logged in with email, or username prefix missing. | Run `docker login` using your username, and tag the image as `username/repo:tag`. |
| `No such image: server:latest` | Tried running `docker tag` against a container name instead of an image. | Use `docker commit <container_name> <username>/<repo>:<tag>` instead. |
| `docker ps` outputs nothing | Containers are stopped/exited. | Run `docker ps -a` to locate stopped containers. |