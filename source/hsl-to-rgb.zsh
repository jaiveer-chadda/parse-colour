#!/usr/bin/env zsh

# ── ── hsl_to_rgb() ── ───────────────────────────────────────────────────── #

function parsecolour::hsl_to_rgb() {
  local -F 10 red grn blu \
    hue=$(( $1 / 360.0 )) \
    sat=$(( $2 / 100.0 )) \
    lig=$(( $3 / 100.0 ))

  if ! (( sat )) { red=$lig  grn=$lig  blu=$lig  # achromatic
  } else {

    # the maximum possible value for each of the RGB channels
    local -F 10 rgb_max=$((
      ( lig < 0.5 )
        ? ( lig * ( sat + 1 ) )
        : ( lig + sat - ( lig * sat ) )
    ))

    # the minimum possible value for each channel
    local -F 10 rgb_min=$(( ( 2.0 * lig ) - rgb_max ))

    red=$( parsecolour::get_hue $rgb_min $rgb_max $(( hue + 1.0 / 3 )) )
    grn=$( parsecolour::get_hue $rgb_min $rgb_max    $hue              )
    blu=$( parsecolour::get_hue $rgb_min $rgb_max $(( hue - 1.0 / 3 )) )
  }

  # `%.0f` : round everything to the nearest integer
  printf $'%.0f %.0f %.0f\n' \
    $(( red * 255 )) $(( grn * 255 )) $(( blu * 255 ))
}

# ── ── hue_to_rgb() ── ───────────────────────────────────────────────────── #

function parsecolour::get_hue() {
  local -F 10 min=$1 max=$2 adj_h=$3  # adjusted hue
  local -F 10 diff6=$(( ( max - min ) * 6.0 ))

  if (( adj_h < 0 )) (( adj_h++ ))
  if (( adj_h > 1 )) (( adj_h-- ))

  if (( adj_h < 1.0 / 6 )) echo $(( min + diff6 * adj_h           )) && return
  if (( adj_h < 1.0 / 2 )) echo $max                                 && return
  if (( adj_h < 2.0 / 3 )) echo $(( min + diff6 * (2.0/3 - adj_h) )) && return

  echo $min
}
