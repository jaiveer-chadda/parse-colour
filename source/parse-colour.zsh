#!/usr/bin/env zsh

#y)TODO:
#y)  - accept different options to turn on/off specific outputs

alias parse-col{o{u,}r,}=parsecolour

function parsecolour() {

  # —— Environment Setup ———————————————————————————————— #

  setopt local_options warn_create_global

  if ! { command -v parsecolour::{hsl_to_rgb,get_hue} &>/dev/null; } {
    source "${${(%):-%x}:h}/hsl-to-rgb.zsh"
  }

  # —— Constants ———————————————————————————————————————— #

  local -r digs='( |)[0-9](#c1,3)'
  local -r decm="$digs(.[0-9]##|)( |)"
  local -r degs="$decm(°|deg(s|)|)"
  local -r perc="$decm(%|)"

  # —— Options Parsing —————————————————————————————————— #

  local u_colour
  local -i 2 do_colour=-1  # -1 = auto,  0 = never,  1 = always
  local opt OPTARG OPTIND

  while { getopts 'c:' opt; } { #
    case "$opt" {
      ( c ) u_colour="$OPTARG" ;;
    }
  }
  shift 'OPTIND - 1'

  if [[ "$u_colour" == 'always' ]] do_colour=1
  if [[ "$u_colour" == 'never'  ]] do_colour=0
  # else do_colour = -1

  # ————————————————————————————————————————————————————— #

  # turn any amount of whitespace into a single space
  # then remove the leading and traling spaces
  # then make the whole thing lowercase
  local -r input="${(L)${${(*)*//[[:space:]]##/ }# }% }"

  # —— Setup ———————————————————————————————————————————— #

  local -a rgb hsl
  local col formatted_input

  # ————————————————————————————————————————————————————— #

  setopt extended_glob

  # ── ── Hex ── ──────────────────────────────────────── #

  if [[ "$input" == (\#|)( |)([0-9a-f](#c3))(#c1,2) ]] {
    #¬ `#807ded` `#87E` `807DED` `87e`
    col="${input#\#}"  # remove the leading hash if it exists

    # if it's a 3-digit hex value, duplicate every char to make it 6-digits
    if (( $#col == 3 )) { rgb=( $col[1]$col[1] $col[2]$col[2] $col[3]$col[3] )
    } else              { rgb=( $col[1,2]      $col[3,4]      $col[5,6]   ); }

    # convert each of the digits from hex to decimal
    rgb=(  $(( 16#$rgb[1] ))  $(( 16#$rgb[2] ))  $(( 16#$rgb[3] ))  )
    formatted_input="#${(U)col}"

  # ── ── RGB ── ──────────────────────────────────────── #

  } elif [[ "$input" == (rgb|)( |)('('|)$~decm((,|)$~decm)(#c2)(')'|) ]] {
    #¬ `rgb(128, 125, 237)`   `rgb(  128,125 237)`   `(  128   125   237   )`
    #¬ `128 125 237`   `128,125,237`

    # remove the leading `rgb` and `(`, and remove the trailing `)`
    # then replace all non-digits with spaces
    col="${${${input#(rgb|)(\(|)}%\)}//[^0-9]/ }"

    # split at every space, then remove empty elements (`:#`)
    rgb=( "${(@)${(@s: :)col}:#}" )

    formatted_input="rgb( ${(j:, :)rgb} )"

    # if either of the last two digits are over 255, we know that the value
    #  is definitely out of bounds, so print an error and exit immediately
    if (( rgb[2] > 255.0 || rgb[3] > 255.0 )) {
      echo "$0: rgb-bounds" >&2
      return 1
    }
    # but if the first digit is between 266 and 360, it might actually be an
    #  hsl colour. in that case, reset `$@rgb` so we can test for hsl instead
    if (( 255.0 < rgb[1] && rgb[1] <= 360.0 )) rgb=()
  }

  # ── ── HSL ── ──────────────────────────────────────── #

  # only check for hsl if `$@rgb` hasn't been set yet
  if ! (( $#rgb )) &&
    [[ "$input" == (hsl|)( |)('('|)$~degs(( |)[\ ,]$~perc)(#c2)(')'|) ]] {

    # remove the leading `hsl` and `(`, and remove the trailing `)`
    # then replace all non-digits (or decimals) with spaces
    col="${${${input#(hsl|)(\(|)}%\)}//[^0-9.]/ }"

    # split at every space, then remove empty elements (`:#`)
    hsl=( "${(@)${(@s: :)col}:#}" )

    # if any of the values are out of bounds, throw an error
    if (( hsl[1] > 360.0 || hsl[2] > 100.0 || hsl[2] > 100.0 )) {
      echo "$0: hsl-bounds" >&2
      return 1
    }

    rgb=( "${(@s: :)$( parsecolour::hsl_to_rgb "${(@)hsl}" )}" )
    formatted_input="hsl( $hsl[1]°, $hsl[2]%, $hsl[3]% )"
  }

  # ————————————————————————————————————————————————————— #

  # check that something was actually generated
  if ! (( $#rgb )) { echo "$0: colour-format" >&2; return 1; }

  # —— Output Colour ———————————————————————————————————— #

  # only display the colour if
  #  – the user asked for it (`-c always`)
  # OR
  #  – the output is a tty,        AND
  #  – `$NO_COLOR` is unset,       AND
  #  – the term has 24-bit colour, AND
  #  – the user didn't turn it off (`-c never`)

  local esc_colour= reset=
  if (( do_colour == 1 )) || [[
    -t 1
    && -z "$NO_COLOR"
    && "$COLORTERM" == (24bit|truecolor)
    && "$do_colour" -ne 0 
  ]] {

    # W3C – https://www.w3.org/TR/AERT/#color-contrast
    local -rF 10 luminance=$(( rgb[1]*0.299 + rgb[2]*0.587 + rgb[3]*0.114 ))

    # Mark Ransom – https://stackoverflow.com/a/946734
    # (tho I changed the exact cutoff)
    local -ri 10 fg_colour=$(( luminance > 132.0 ? 30 : 37 ))

    esc_colour=$'\e[1;'"$fg_colour;48;2;${(j:;:)rgb}m"
    reset=$'\e[m'
  }

  echo -n "$esc_colour$formatted_input$reset"  # hsl( 242°, 75%, 71% )¬

  if [[ "$formatted_input" != 'rgb'* ]] {  # == rgb(129, 126, 237)¬
    echo -n " == ${esc_colour}rgb( ${(j:, :)rgb} )$reset"
  }
  echo
}

# spell:ignore perc decm
