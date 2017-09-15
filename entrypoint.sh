#!/bin/bash

# source the base scripts
. ~/dotfiles/base/.exports
. ~/dotfiles/base/.imports
. ~/dotfiles/base/.aliases
. ~/dotfiles/base/.functions

# register the global gitignore commands
git config --global core.excludesfile ~/dotfiles/.gitignore

# source the custom scripts
if [ -f ~/dotfiles/custom/.exports ] ; then
  . ~/dotfiles/custom/.exports
fi
if [ -f ~/dotfiles/custom/.imports ] ; then
  . ~/dotfiles/custom/.imports
fi
if [ -f ~/dotfiles/custom/.aliases ] ; then
  . ~/dotfiles/custom/.aliases
fi
if [ -f ~/dotfiles/custom/.functions ] ; then
  . ~/dotfiles/custom/.functions
fi

# make sure nvm directory exists
if [ ! -d ~/.nvm ] ; then
  mkdir ~/.nvm
fi
