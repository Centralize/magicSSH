# SSH2 Manager

A console-based SSH connection manager with an interactive `dialog` interface. This script simplifies managing multiple SSH connections by providing a menu-driven system to add, edit, remove, list, and connect to servers, as well as manage SSH keys.

## Features

*   **Add/Edit/Remove Servers:** Easily manage your SSH server configurations.
*   **Store Connection Details:** Persistently saves server name, hostname/IP, port, username, SSH key path, and notes.
*   **Interactive Interface:** Uses `dialog` for a user-friendly console experience.
*   **SSH Key Management:**
    *   Supports automatic detection of default SSH keys (`id_rsa`, `id_ed25519`, etc.).
    *   Allows specifying custom SSH key paths.
    *   Option for password-based authentication.
    *   **Copy SSH Key:** Integrates `ssh-copy-id` to easily copy your public SSH key to remote servers for passwordless login.
    *   Automatically adds server host keys to `known_hosts` and accepts new fingerprints.
*   **Quick Connection:** Connect to any configured server with a single selection.
*   **Dependency Check:** Verifies the presence of required tools (`dialog`, `ssh`, `ssh-copy-id`, `ssh-keyscan`) on startup.

## Dependencies

The script requires the following command-line tools to be installed on your system:

*   `dialog`: For creating the interactive menu interface.
*   `openssh-client`: Provides `ssh`, `ssh-copy-id`, and `ssh-keyscan` for SSH connectivity and key management.

### Installation on Debian/Ubuntu

```bash
sudo apt update
sudo apt install dialog openssh-client
```

### Installation on Fedora/CentOS/RHEL

```bash
sudo dnf install dialog openssh-clients
```

## Installation

1.  **Clone the repository (or download the script):**
    ```bash
    git clone https://github.com/your-username/magicSSH.git
    cd magicSSH
    ```
    *(Replace `https://github.com/your-username/magicSSH.git` with the actual repository URL if different.)*

2.  **Make the script executable:**
    ```bash
    chmod +x ssh2manager.sh
    ```

3.  **Optional: Add to your PATH for easy access:**
    You can move the script to a directory included in your system's `PATH` (e.g., `/usr/local/bin` or `~/bin`).
    ```bash
    sudo mv ssh2manager.sh /usr/local/bin/
    ```
    Or for user-specific installation:
    ```bash
    mkdir -p ~/bin
    mv ssh2manager.sh ~/bin/
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc # Or ~/.zshrc, etc.
    source ~/.bashrc
    ```

## Usage

To start the SSH2 Manager, simply run the script from your terminal:

```bash
./ssh2manager.sh
# Or if installed in PATH:
ssh2manager.sh
```

You will be presented with a main menu:

```
+---------------------+
|    SSH2 Manager v1.0|
+---------------------+
| Choose an option:   |
| 1) Connect to Server|
| 2) Add New Server   |
| 3) Edit Server      |
| 4) Remove Server    |
| 5) Copy SSH Key to S|
| 6) List All Servers |
| 7) About            |
| 8) Exit             |
+---------------------+
```

Navigate the menu using arrow keys and press `Enter` to select an option.

### Configuration Storage

The script stores its configuration and server details in the following directory and file:

*   **Configuration Directory:** `$HOME/.ssh2manager/`
*   **Servers File:** `$HOME/.ssh2manager/servers.conf`

The `servers.conf` file is a plain text file where each line represents a server entry, with fields separated by a pipe (`|`) character:
`Name|Host|Port|Username|SSH_Key_Path|Note`

Example `servers.conf` entry:
```
MyWebServer|web.example.com|22|user1|auto|Production web server
DevBox|192.168.1.100|2222|devuser|/home/user/.ssh/id_custom|Development VM
```

## SSH Key Management

When adding or editing a server, you can specify how SSH key authentication is handled:

*   **`auto` (default):** The script will automatically try to find and use a default SSH key (e.g., `id_ed25519`, `id_rsa`) from your `$HOME/.ssh` directory.
*   **`none`:** Forces the SSH connection to use password authentication.
*   **Custom Path:** You can browse and select a specific SSH private key file.

### Copy SSH Key to Server

The "Copy SSH Key to Server" option uses `ssh-copy-id` to securely transfer your public SSH key to the remote server. This allows for passwordless authentication after the initial setup. The script will guide you through selecting the server and will use the SSH key configured for that server (or your default key if `auto` or `none` is selected).

## Author

SSH2 Manager Script

## License

This project is open-source. Please refer to the script's source code for any specific licensing information.
