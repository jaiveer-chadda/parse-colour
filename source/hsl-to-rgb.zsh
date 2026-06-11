#!/usr/bin/env zsh

# ── ── hsl_to_rgb() ── ───────────────────────────────────────────────────── #

function parsecolour::hsl_to_rgb() {
  local  -F 10 red grn blu
  local -rF 10 hue=$(( $1 / 360.0 )) \
        saturation=$(( $2 / 100.0 )) \
         lightness=$(( $3 / 100.0 ))

  if ! (( saturation )) {  # achromatic
    red=$lightness  grn=$lightness  blu=$lightness

  } else {
    # the maximum possible value for each of the RGB channels
    local -rF 10 rgb_max=$((
      ( lightness < 0.5 )
        ? ( lightness * ( saturation + 1 ) )
        : ( lightness + saturation - ( lightness * saturation ) )
    ))

    # the minimum possible value for each channel
    local -rF 10 rgb_min=$(( ( 2.0 * lightness ) - rgb_max ))

    red=$( parsecolour::get_hue $rgb_min $rgb_max $(( hue + 1.0 / 3 )) )
    grn=$( parsecolour::get_hue $rgb_min $rgb_max    $hue              )
    blu=$( parsecolour::get_hue $rgb_min $rgb_max $(( hue - 1.0 / 3 )) )
  }

  printf "%.${decm_plcs:-1}f " \
    $(( red * 255 )) $(( grn * 255 )) $(( blu * 255 ))
}

# ── ── hue_to_rgb() ── ───────────────────────────────────────────────────── #

function parsecolour::get_hue() {
  local -rF 10   min=$1 max=$2
  local  -F 10 adj_h=$3  # adjusted hue
  local -rF 10 diff6=$(( ( max - min ) * 6.0 ))

  if (( adj_h < 0 )) (( adj_h++ ))
  if (( adj_h > 1 )) (( adj_h-- ))

  if (( adj_h < 1.0 / 6 )) echo $(( min + diff6 * adj_h           )) && return
  if (( adj_h < 1.0 / 2 )) echo $max                                 && return
  if (( adj_h < 2.0 / 3 )) echo $(( min + diff6 * (2.0/3 - adj_h) )) && return

  echo $min
}

# spell:ignore decm
