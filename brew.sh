#!/bin/bash

# Install command-line tools using Homebrew

# Make sure we’re using the latest Homebrew
brew update

# Upgrade any already-installed formulae
brew upgrade

# GNU core utilities (those that come with OS X are outdated)
brew install coreutils
brew install moreutils

# GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
brew install findutils

# GNU `sed`, overwriting the built-in `sed`
brew install gnu-sed --with-default-names

# Bash 4
# Note: don’t forget to add `/usr/local/bin/bash` to `/etc/shells` before running `chsh`.
brew install bash
brew install bash-completion
brew install homebrew/completions/brew-cask-completion

# Install wget with IRI support
brew install wget --with-iri

# Install more recent versions of some OS X tools
brew install vim --with-override-system-vi
brew install homebrew/dupes/nano
brew install homebrew/dupes/grep
brew install homebrew/dupes/openssh
brew install homebrew/dupes/screen

# Install other useful binaries
brew install git
brew install imagemagick --with-webp
brew install ffmpeg --with-libvpx
brew install terminal-notifier
brew install openconnect

# Install exa (https://the.exa.website/)
brew install exa

# Install go
brew install go

# Install kubernetes
brew install kubernetes-cli
brew install kubernetes-helm

# Install tldr
brew install tldr

# Remove outdated versions from the cellar
brew cleanup

# install tools for gpg
brew install gnupg gnupg2

# install terraform
brew install terraform
