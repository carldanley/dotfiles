# vim: set ft=tmux:

# set -g default-terminal 'tmux-256color'
set -as terminal-features ',xterm*:RGB'
set-option -g focus-events on
set -gw mouse on
set -g automatic-rename off
# set -g allow-passthrough on
set -g status-interval 5
set set-clipboard on
set -s escape-time 50
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
set -gw xterm-keys on
set -g history-limit 10000
set-option -g clock-mode-style 24
