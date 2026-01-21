# SSH Key Setup for ISO Builder

This guide explains how to embed SSH keys in your custom NixOS installer ISO so you can pull config changes from git during installation.

## ⚠️ Security Warning

**IMPORTANT:** Embedding SSH private keys in ISO files is a security risk:
- The ISO artifact will contain your private key
- Anyone with access to the ISO can extract and use the key
- Only use this for:
  - Private repositories
  - Deploy keys with limited access (read-only, single repo)
  - Development/testing environments

**Recommended:** Use a dedicated deploy key with minimal permissions instead of your personal SSH key.

## Setup Options

### Option 1: GitHub Actions (Automated Builds)

1. **Create GitHub Secrets:**
   
   **SSH Key Secret:**
   - Go to your repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `SSH_PRIVATE_KEY`
   - Value: Paste your **entire** private key (including `-----BEGIN ... KEY-----` and `-----END ... KEY-----` lines)
   - Click "Add secret"
   
   **Git Repository URL Secret (Optional but recommended):**
   - Click "New repository secret" again
   - Name: `GIT_REPO_URL`
   - Value: Your git repository URL (e.g., `git@github.com:username/repo.git`)
   - Click "Add secret"

2. **The workflow will automatically:**
   - Detect the secrets
   - Embed the SSH key and repo URL in the ISO
   - Show a warning in the build logs

3. **To use a deploy key instead:**
   ```bash
   # Generate a new deploy key (on your local machine)
   ssh-keygen -t ed25519 -f ~/.ssh/nixos-deploy-key -N ""
   
   # Add the PUBLIC key to your GitHub repo:
   # Settings → Deploy keys → Add deploy key
   # Paste the contents of ~/.ssh/nixos-deploy-key.pub
   
   # Add the PRIVATE key to GitHub Secrets as SSH_PRIVATE_KEY
   cat ~/.ssh/nixos-deploy-key
   # Copy the entire output and paste into GitHub Secrets
   ```

### Option 2: Local Build

Build the ISO locally with your SSH key:

```bash
# Set the SSH key path and build
SSH_KEY_PATH=~/.ssh/id_ed25519 nix build .#packages.x86_64-linux.iso

# Or with explicit path
SSH_KEY_PATH=/home/user/.ssh/id_rsa nix build .#packages.x86_64-linux.iso
```

## Using the ISO

Once the ISO is built with an SSH key and repo URL:

1. **Boot into the installer**
2. **Update config from git:**
   ```bash
   # If repo URL is embedded, just specify the branch:
   update-config main
   # or
   update-config release
   
   # If repo URL is NOT embedded, specify it:
   update-config git@github.com:yourusername/yourrepo.git main
   
   # Or set as environment variable
   export GIT_REPO=git@github.com:yourusername/yourrepo.git
   update-config
   ```

3. **Use the updated config:**
   ```bash
   cd /tmp/nixos-config-update
   sudo ./simple-install.sh
   ```

## Troubleshooting

### "Permission denied (publickey)" error

- Check that the SSH key is embedded: `ls -la /etc/nixos-config/.ssh/`
- Verify the key has correct permissions: `chmod 600 ~/.ssh/id_key`
- Test SSH connection: `ssh -T git@github.com`

### Key not found in ISO

- Check build logs for SSH key warnings
- Verify the GitHub Secret is set correctly
- For local builds, ensure `SSH_KEY_PATH` is set and the file exists

### Deploy Key Best Practices

1. Create a key specifically for this purpose
2. Give it a descriptive name: `nixos-iso-deploy-key`
3. Add only the **public** key to your repo as a deploy key
4. Set it to **read-only** access
5. Only add the **private** key to GitHub Secrets

## GitHub Secrets Summary

Set these secrets in your repository (Settings → Secrets and variables → Actions):

1. **`SSH_PRIVATE_KEY`** (Required for private repos)
   - Your SSH private key content
   - Allows cloning private repositories

2. **`GIT_REPO_URL`** (Optional but recommended)
   - Your git repository URL
   - Example: `git@github.com:username/repo.git`
   - Makes `update-config` easier to use (just specify branch)

## Removing SSH Key Support

To build without SSH key:
- Don't set the `SSH_PRIVATE_KEY` secret in GitHub Actions
- Don't set `SSH_KEY_PATH` for local builds
- The ISO will still work, but `update-config` won't be able to clone private repos

To build without default repo URL:
- Don't set the `GIT_REPO_URL` secret
- You'll need to specify the repo URL when using `update-config`

