#!/usr/bin/env zsh

alias parse-colo{u,}r=parsecolour

#y)TODO: accept different options to turn on/off specific outputs

function parsecolour() {

  # —— Constants ——————————————————————————————————————————————— #

  setopt local_options extended_glob warn_create_global

  local -r ESC=$'\e'

  local -r digs='[0-9]{1,3}'
  local -r numb=" *$digs *"             # " *[0-9]{1,3} *"
  local -r degs=" *$digs(°|degs?)? *"   # " *[0-9]{1,3}(°|degs?)? *"
  local -r perc=" *$digs(\.$digs%?)? *" # " *[0-9]{1,3}(\.[0-9]{1,3}%?)? *"

  # —— Options Parsing ————————————————————————————————————————— #

  local u_colour
  local -i 2 do_colour=-1  # -1 = auto,  0 = never,  1 = always

  local opt OPTARG OPTIND
  while { getopts c: opt; } { case "$opt" { ( c ) u_colour="$OPTARG";; }; }
  shift 'OPTIND - 1'

  if [[ "$u_colour" == 'always' ]] do_colour=1
  if [[ "$u_colour" == 'never'  ]] do_colour=0

  # —— Setup ——————————————————————————————————————————————————— #

  local -a rgb hsl
  local -i 2 try_hsl
  local col formatted_input

  # ———————————————————————————————————————————————————————————— #

  # ── ── Hex ── ─────────────────────────────────────────────── #

  if [[ "$*" == (|'#')([0-9a-fA-F](#c3))(#c1,2) ]] {
    #¬ `#807ded` `#87E` `807DED` `87e`
    col="${*#\#}"  # remove the leading hash if it exists

    # if it's a 3-digit hex value, duplicate every character to make it 6-digit
    if (( $#col == 3 )) { rgb=( $col[1]$col[1] $col[2]$col[2] $col[3]$col[3] )
    } else              { rgb=( $col[1,2]      $col[3,4]      $col[5,6]   ); }

    # convert each of the digits from hex to decimal
    rgb=(  $(( 16#$rgb[1] ))  $(( 16#$rgb[2] ))  $(( 16#$rgb[3] ))  )
    formatted_input="#${(L)col}"

  # ── ── RGB ── ─────────────────────────────────────────────── #

  } elif [[ "$*" =~ "^ *((rgb|RGB)?\()?${~numb},?${~numb},?${~numb}\)? *$" ]] {
    #¬ `rgb(128, 125, 237)`   `rgb(  128,125 237)`   `(  128   125   237   )`
    #¬ `128 125 237`   `128,125,237`

    # remove the leading `rgb` and `(`, and remove the trailing `)`
    # then replace all non-digits with spaces
    col="${${${${*#rgb}#\(}%\)}//[^0-9]/ }"
    # split at every space, then remove empty elements (`:#`)
    rgb=( "${(@)${(@s: :)col}:#}" )
    formatted_input="rgb( ${(j:, :)rgb} )"

    # if either of the last two digits are over 255, we know that the value
    #  is definitely out of bounds, so print an error and exit immediately
    if (( rgb[2] > 255 || rgb[3] > 255 )) {
      echo "$0: rgb-bounds" >&2
      return 1
    }
    # but if the first digit is between 266 and 360, it might actually be
    #  an hsl colour, so reset `$@rgb`, so we can try and test for hsl instead
    if (( 255 < rgb[1] && rgb[1] <= 360 )) rgb=()
  }

  # ── ── HSL ── ─────────────────────────────────────────────── #

  # only check for hsl if `$@rgb` hasn't been set yet
  if ! (( $#rgb )) \
    && [[ "$*" =~ "^ *((hsl|HSL)?\()?${~degs},?${~perc},?${~perc}\)? *$" ]] {

    # remove the leading `hsl` and `(`, and remove the trailing `)`
    # then replace all non-digits (or decimals) with spaces
    col="${${${${*#hsl}#\(}%\)}//[^0-9.]/ }"
    # split at every space, then remove empty elements (`:#`)
    hsl=( "${(@)${(@s: :)col}:#}" )

    # if any of the values are out of bounds, throw an error
    if (( hsl[1] > 360 || hsl[2] > 100 || hsl[2] > 100 )) {
      echo "$0: hsl-bounds" >&2
      return 1
    }

    rgb=( "${(@s: :)$( hsl_to_rgb "${(@)hsl}" )}" )
    formatted_input="hsl( $hsl[1]°, $hsl[2]%, $hsl[3]% )"
  } 

  # ———————————————————————————————————————————————————————————— #

  # —— Output Colour ——————————————————————————————————————————— #

  # check that something was actually generated
  if ! (( $#rgb )) { echo "$0: colour-format" >&2; return 1; }

  local esc_colour= reset=
  # only display the colour if
  #  – the user asked for it (`-c always`)
  #  OR
  #  – the output is a tty, AND
  #  – `$NO_COLOR` is unset, AND
  #  – the term supports 24-bit colour, AND
  #  – the user didn't turn it off (`-c never`)
  if (( do_colour == 1 )) || [[
    -t 1
    && -z "${NO_COLOR:-}"
    && "$do_colour" -ne 0 
    && "$COLORTERM" == (24bit|truecolor)
  ]] {
    # W3C – https://www.w3.org/TR/AERT/#color-contrast
    local -rF 10 luminance=$(( rgb[1]*0.299 + rgb[2]*0.587 + rgb[3]*0.114 ))

    # Mark Ransom – https://stackoverflow.com/a/946734
    # (tho I changed the exact cutoff)
    local -ri 10 fg_colour=$(( luminance > 132 ? 30 : 37 ))

    esc_colour="${ESC}[1;$fg_colour;48;2;${(j:;:)rgb}m"
    reset=$'\e[m'
  }

  {
    echo -n "$esc_colour$formatted_input$reset"  # hsl( 242°, 75%, 71% )

    if [[ "$formatted_input" != 'rgb'* ]] {  #  == rgb(129, 126, 237)
      echo -n " == ${esc_colour}rgb( ${(j:, :)rgb} )$reset"
    }
    echo
  } >&2
}

# spell:ignore perc
