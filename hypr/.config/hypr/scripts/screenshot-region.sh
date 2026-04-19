#!/bin/zsh
FILE=~/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png
hyprshot -m region -o ~/Pictures/screenshots -f $(basename $FILE) -z
wl-copy <$FILE
