# Dotfiles

> My attempt at organizing myself across machines via chezmoi.

## First Time Setup

### Secrets

This chezmoi configuration uses 1Password to manage secret injection.

### Templates

To check whether or not a template is pulling secrets correctly, you can run a command like the following:

```bash
chezmoi execute-template "$(cat ./home/private_dot_config/exact_git/dot_gitconfig-work.tmpl)"
```

## GPG Keys

### Generating a new key

To generate a new key, type: `gpg --full-gen-key` (alias: `gpgcreate`).

At the prompt, select the following:

1. type `4` for `(4) RSA (sign only)`
1. keysize: `4096`
1. expiration: choose something reasonable

To confirm the key was created, type: `gpg --list-secret-keys --keyid-format SHORT` (alias: `gpglist`)

### Restarting gpg-agent

If your GPG agent is having issues, you can restart it with:

```sh
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
```

^ (alias: `gpgrestart`)

### Adding multiple emails

You can add multiple email addresses by doing the following:

1. Edit the key: `gpg --edit-key 674CB45A` (alias: `gpgedit 674CB45A`)
1. In gpg prompt, type `adduid`; follow the prompts
1. Then, update the trust for the new identity: `uid 2` and `trust`; type `5` (for "I trust ultimately")
1. Type `save`

### Exporting GPG key

To export the GPG key for use with something like GitHub or GitLab, type: `gpg --armor --export 674CB45A` (alias: `gpgexport 674CB45A`)
