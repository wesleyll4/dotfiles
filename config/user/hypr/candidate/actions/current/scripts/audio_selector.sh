#!/bin/bash

# Puxa a lista de saídas (sinks) usando pactl
selected=$(pactl list short sinks | awk '{print $2}' | rofi -dmenu -p "Saída de Áudio" -i)

# Se algo foi selecionado, define como padrão
if [ ! -z "$selected" ]; then
  pactl set-default-sink "$selected"
  notify-send "Áudio" "Saída alterada para: $selected" -i audio-speakers
fi
