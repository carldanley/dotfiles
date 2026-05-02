# Dotfiles

> Personal machine bootstrap and dotfile management with `chezmoi`.

## Bootstrap

Run bootstrap as your normal user, never with `sudo` or as `root`.

On a brand new Mac:

```bash
./install.sh --prereqs --import-gpg --gpg-vault "<YOUR_1PASSWORD_VAULT>" --gpg-item "<YOUR_GPG_BUNDLE_ITEM>"
./install.sh
```

If `brew` or `op` is not available in the current shell after prerequisites finish, either open a new terminal or run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## Prerequisites

`./install.sh --prereqs` installs the minimum clean-machine dependencies before the full `chezmoi` apply:

- Xcode Command Line Tools check
- Homebrew
- `chezmoi`
- `gnupg`
- `pinentry-mac`
- `1password-cli`
- `1password` app if it is not already installed

The prerequisites flow also:

- refuses to run as `root`
- uses Homebrew’s normal privilege prompts when needed
- configures `gpg-agent` to use `pinentry-mac` before importing GPG material

Use `--dry-run` to preview actions:

```bash
./install.sh --prereqs --dry-run
```

Optional 1Password-backed imports are also available during prerequisites:

- `--import-gpg` imports your GPG signing key bundle
- `--import-talos` imports a Talos client config attachment

## Doctor

Run doctor before a full apply if you want a readiness check:

```bash
./install.sh --doctor
```

Doctor currently checks:

- Xcode Command Line Tools on macOS
- Homebrew and `chezmoi`
- 1Password CLI and vault access
- `gpg`, `gpgconf`, and `pinentry-mac`
- whether any secret GPG keys are installed
- whether the local `chezmoi` signing key exists, has signing capability, and is expired or expiring soon
- whether `talosctl` is installed and whether a readable Talos config exists

You can adjust the expiry warning threshold:

```bash
./install.sh --doctor --gpg-expiry-warning-days 14
```

## 1Password Setup

This repo depends on 1Password for template rendering and GPG bootstrap.

Before running the full install, open and unlock the 1Password app and enable CLI integration:

1. Open `1Password`
2. Go to `Settings > Developer`
3. Turn on `Integrate with 1Password CLI`

The CLI may ask for approval through the desktop app while reading vault data.
This repo also exports `OP_BIOMETRIC_UNLOCK_ENABLED=true` by default for shell sessions and bootstrap scripts unless you override it.

If you want to verify the CLI manually:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
op vault list
```

## GPG Bootstrap

`./install.sh --prereqs --import-gpg` imports GPG material from a 1Password item that you identify at runtime with `--gpg-vault` and `--gpg-item`, or with these environment variables:

```bash
export DOTFILES_GPG_BUNDLE_VAULT="<YOUR_1PASSWORD_VAULT>"
export DOTFILES_GPG_BUNDLE_ITEM="<YOUR_GPG_BUNDLE_ITEM>"
./install.sh --prereqs --import-gpg
```

The importer currently expects the bundle item to contain:

- a `SigningKey` field
- a `Fingerprint` field
- a `Public` attachment
- a `SecretSubKeys` attachment
- an `Ownertrust` attachment
- a `Revocation` attachment

Important: the `SecretSubKeys` attachment name is historical. Its current contents should be a full secret key export if your signing setup still signs with the primary key.

After a successful import:

- the revocation certificate is copied to `~/.local/share/dotfiles-backups/gpg-revocation-cert.rev`
- a local `chezmoi` config is written to `~/.config/chezmoi/chezmoi.yaml` with `data.git.signingkey`
- the full `chezmoi` apply can use that signing key without prompting again

## Talos Bootstrap

`./install.sh --prereqs --import-talos` imports a Talos client config attachment from a 1Password item that you identify at runtime with `--talos-vault`, `--talos-item`, and optionally `--talos-file`, or with these environment variables:

```bash
export DOTFILES_TALOS_CONFIG_VAULT="<YOUR_1PASSWORD_VAULT>"
export DOTFILES_TALOS_CONFIG_ITEM="<YOUR_TALOS_CONFIG_ITEM>"
export DOTFILES_TALOS_CONFIG_FILE="<YOUR_TALOS_ATTACHMENT_NAME>"
./install.sh --prereqs --import-talos
```

The Talos importer currently expects:

- an item in 1Password that contains a file attachment with the Talos client config
- a default attachment name of `talosconfig` unless you override it with `--talos-file`

After a successful import:

- the file is written to `~/.config/talos/config`
- a machine-only secret reference is written to `~/.config/chezmoi/talos-config-secret-ref` so future `chezmoi` applies can keep `~/.config/talos/config` in sync
- if `talosctl` is already installed, the importer validates the config with `talosctl config info`

To test the Talos config manually:

```bash
TALOSCONFIG="$HOME/.config/talos/config" talosctl config info
TALOSCONFIG="$HOME/.config/talos/config" talosctl health --wait-timeout 30s
```

`talosctl config info` verifies that the file is readable and has a usable current context. `talosctl health` is the real connectivity check against the cluster.

## Refreshing the GPG Bundle

On the source machine, export the key material:

```bash
gpg --armor --export <YOUR_GPG_KEY_ID> > gpg-public.asc
gpg --armor --export-secret-keys <YOUR_GPG_KEY_ID> > gpg-secret-key.asc
gpg --export-ownertrust > gpg-ownertrust.txt
```

Export or copy the revocation certificate too. It is commonly stored under:

```bash
~/.gnupg/openpgp-revocs.d/
```

Update your existing bundle item in 1Password:

```bash
op item edit "<YOUR_GPG_BUNDLE_ITEM>" --vault "<YOUR_1PASSWORD_VAULT>" \
  'Fingerprint[text]=<YOUR_GPG_FINGERPRINT>' \
  'SigningKey[text]=<YOUR_GPG_KEY_ID>' \
  'Public[file]=/full/path/gpg-public.asc' \
  'SecretSubKeys[file]=/full/path/gpg-secret-key.asc' \
  'Ownertrust[file]=/full/path/gpg-ownertrust.txt' \
  'Revocation[file]=/full/path/gpg-revocation-cert.rev'
```

If you rename the bundle fields or attachment labels, update `install-prerequisites.sh` accordingly.

## Full Apply

After prerequisites are in place:

```bash
./install.sh
```

This runs `chezmoi init --apply` against the repository and performs the full dotfile provisioning flow.

## Terminal Themes

This repo currently manages `kitty`, not iTerm2, as the terminal with a committed default theme:

- `kitty` theme: `Catppuccin-Mocha`
- source: `home/private_dot_config/exact_kitty/current-theme.conf`

iTerm2 color presets can still be installed manually when you want them.

To import an `.itermcolors` preset in iTerm2:

1. Open `iTerm2`
2. Go to `Settings > Profiles > Colors`
3. Click `Color Presets...`
4. Choose `Import...`
5. Select the `.itermcolors` file
6. Re-open `Color Presets...` and choose the imported preset for the profile you want

Example for Catppuccin Frappe:

```bash
curl -fsSL "https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Catppuccin%20Frappe.itermcolors" -o ~/Downloads/Catppuccin-Frappe.itermcolors
```

Then import `~/Downloads/Catppuccin-Frappe.itermcolors` through the iTerm2 UI.

## Template Testing

To test whether a template is resolving 1Password-backed values correctly:

```bash
chezmoi execute-template "$(cat ./home/private_dot_config/exact_git/dot_gitconfig-work.tmpl)"
```

## GPG Notes

Useful commands:

```bash
gpg --list-secret-keys --keyid-format LONG
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
gpg --armor --export <YOUR_GPG_KEY_ID>
```
