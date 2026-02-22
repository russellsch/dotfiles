# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# Chroma for Hydra CLI override grammar (sourced by init.zsh)
# Highlights: prefix operators (~, +, ++), config keys, =, typed values
# (keywords, numbers, quoted strings, interpolations, functions), and flags.

# --- Helper: add a highlight region ---
# Reads __start_pos and PREBUFFER from caller via dynamic scoping.
_hydra_hl() {
    integer _hs=$(( __start_pos + $1 - ${#PREBUFFER} ))
    integer _he=$(( __start_pos + $2 - ${#PREBUFFER} ))
    (( _hs >= 0 )) && reply+=("$_hs $_he ${FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}$3]}")
}

# --- Helper: highlight a Hydra value string ---
_hydra_hl_value() {
    local _v="$1"
    integer _off=$2 _vlen=${#_v}

    (( _vlen == 0 )) && return

    local _vl="${_v:l}"

    # Quoted strings
    if [[ "$_v" = \'*\' && _vlen -ge 2 ]]; then
        _hydra_hl $_off $(( _off + _vlen )) single-quoted-argument
        return
    fi
    if [[ "$_v" = \"*\" && _vlen -ge 2 ]]; then
        _hydra_hl $_off $(( _off + _vlen )) double-quoted-argument
        return
    fi

    # Case-insensitive keyword match
    case "$_vl" in
        true|false|null|inf|-inf|+inf|nan)
            _hydra_hl $_off $(( _off + _vlen )) reserved-word; return ;;
    esac

    # Integer: optional sign, digits (underscore grouping allowed)
    if [[ "$_v" = [+-]#[0-9][0-9_]# && "$_v" != *[a-zA-Z]* ]]; then
        _hydra_hl $_off $(( _off + _vlen )) for-loop-number; return
    fi
    # Float: digits with dot and/or exponent
    if [[ "$_v" = [+-]#[0-9_]##(.[0-9_]#|)[eE][+-]#[0-9_]## || "$_v" = [+-]#[0-9_]#.[0-9_]# || "$_v" = [+-]#[0-9_]#. ]]; then
        _hydra_hl $_off $(( _off + _vlen )) for-loop-number; return
    fi

    # Standalone interpolation: ${...}
    if [[ "$_v" = '${'*'}' ]]; then
        _hydra_hl $_off $(( _off + _vlen )) back-or-dollar-double-quoted-argument
        return
    fi

    # Function call: name(args)
    if [[ "$_v" = (#b)([a-zA-Z_][a-zA-Z0-9_]#)\((*)\) ]]; then
        local _fname="${match[1]}" _fargs="${match[2]}"
        integer _fnlen=${#_fname}
        _hydra_hl $_off $(( _off + _fnlen )) builtin
        _hydra_hl $(( _off + _fnlen )) $(( _off + _fnlen + 1 )) subtle-separator
        _hydra_hl $(( _off + _vlen - 1 )) $(( _off + _vlen )) subtle-separator
        _hydra_hl_arglist "$_fargs" $(( _off + _fnlen + 1 ))
        return
    fi

    # List literal: [...]
    if [[ "$_v" = '['*']' ]]; then
        _hydra_hl $_off $(( _off + 1 )) subtle-separator
        _hydra_hl $(( _off + _vlen - 1 )) $(( _off + _vlen )) subtle-separator
        _hydra_hl_arglist "${_v:1:$(( _vlen - 2 ))}" $(( _off + 1 ))
        return
    fi

    # Dict literal: {...}
    if [[ "$_v" = '{'*'}' ]]; then
        _hydra_hl $_off $(( _off + 1 )) subtle-separator
        _hydra_hl $(( _off + _vlen - 1 )) $(( _off + _vlen )) subtle-separator
        _hydra_hl_dict "${_v:1:$(( _vlen - 2 ))}" $(( _off + 1 ))
        return
    fi

    # Comma-separated sweep at top level: a,b,c
    if [[ "$_v" = *,* ]]; then
        _hydra_hl_arglist "$_v" $_off
        return
    fi

    # Unquoted value — scan for embedded interpolations
    _hydra_hl_unquoted "$_v" $_off
}

# --- Helper: highlight comma-separated argument list ---
_hydra_hl_arglist() {
    local _list="$1" _elem _ch
    integer _loff=$2 _depth=0 _start=0 _i _llen=${#_list}

    (( _llen == 0 )) && return

    for (( _i=0; _i < _llen; _i++ )); do
        _ch="$_list[$((_i+1))]"
        case "$_ch" in
            '('|'['|'{') (( _depth++ )) ;;
            ')'|']'|'}') (( _depth-- )) ;;
            ',')
                if (( _depth == 0 )); then
                    _elem="${_list:$_start:$(( _i - _start ))}"
                    _hydra_hl_maybe_named "$_elem" $(( _loff + _start ))
                    _hydra_hl $(( _loff + _i )) $(( _loff + _i + 1 )) subtle-separator
                    (( _start = _i + 1 ))
                fi
                ;;
        esac
    done
    # Last element
    _elem="${_list:$_start}"
    [[ -n "$_elem" ]] && _hydra_hl_maybe_named "$_elem" $(( _loff + _start ))
}

# --- Helper: highlight element, detecting named args (name=value) ---
_hydra_hl_maybe_named() {
    local _mn="$1"
    integer _moff=$2
    if [[ "$_mn" = (#b)([a-zA-Z_][a-zA-Z0-9_]#)=(*) ]]; then
        integer _nlen=${#match[1]}
        _hydra_hl $_moff $(( _moff + _nlen )) assign
        _hydra_hl $(( _moff + _nlen )) $(( _moff + _nlen + 1 )) for-loop-separator
        _hydra_hl_value "${match[2]}" $(( _moff + _nlen + 1 ))
    else
        _hydra_hl_value "$_mn" $_moff
    fi
}

# --- Helper: highlight dict key:value pairs ---
_hydra_hl_dict() {
    local _dict="$1" _pair _ch
    integer _doff=$2 _depth=0 _start=0 _i _dlen=${#_dict}

    (( _dlen == 0 )) && return

    for (( _i=0; _i < _dlen; _i++ )); do
        _ch="$_dict[$((_i+1))]"
        case "$_ch" in
            '('|'['|'{') (( _depth++ )) ;;
            ')'|']'|'}') (( _depth-- )) ;;
            ',')
                if (( _depth == 0 )); then
                    _pair="${_dict:$_start:$(( _i - _start ))}"
                    _hydra_hl_dictpair "$_pair" $(( _doff + _start ))
                    _hydra_hl $(( _doff + _i )) $(( _doff + _i + 1 )) subtle-separator
                    (( _start = _i + 1 ))
                fi
                ;;
        esac
    done
    _pair="${_dict:$_start}"
    [[ -n "$_pair" ]] && _hydra_hl_dictpair "$_pair" $(( _doff + _start ))
}

# --- Helper: highlight a single dict key:value ---
_hydra_hl_dictpair() {
    local _pair="$1"
    integer _poff=$2
    if [[ "$_pair" = (#b)([^:]#):(*)  ]]; then
        integer _klen=${#match[1]}
        _hydra_hl $_poff $(( _poff + _klen )) assign
        _hydra_hl $(( _poff + _klen )) $(( _poff + _klen + 1 )) subtle-separator
        _hydra_hl_value "${match[2]}" $(( _poff + _klen + 1 ))
    fi
}

# --- Helper: highlight unquoted value scanning for interpolations ---
_hydra_hl_unquoted() {
    local _uv="$1" _rest _before _after
    integer _uoff=$2 _pos=0 _j _depth _pre _ilen

    _rest="$_uv"
    while [[ "$_rest" = *'${'* ]]; do
        _before="${_rest%%\$\{*}"
        _pre=${#_before}
        _after="${_rest#*\$\{}"
        # Find matching }
        _depth=1
        for (( _j=0; _j < ${#_after}; _j++ )); do
            case "$_after[$((_j+1))]" in
                '{') (( _depth++ )) ;;
                '}') (( _depth-- )); (( _depth == 0 )) && break ;;
            esac
        done
        if (( _depth == 0 )); then
            _ilen=$(( 2 + _j + 1 ))  # ${ + content + }
            _hydra_hl $(( _uoff + _pos + _pre )) $(( _uoff + _pos + _pre + _ilen )) back-or-dollar-double-quoted-argument
            (( _pos += _pre + _ilen ))
            _rest="${_after:$(( _j + 1 ))}"
        else
            break
        fi
    done
}


# ===== Main chroma function =====
chroma/-hydra-override() {
    (( next_word = 2 | 8192 ))

    local __first_call="$1" __wrd="$2" __start_pos="$3" __end_pos="$4"
    local __style
    integer __idx1 __idx2

    (( __first_call )) && {
        # First call — the command token itself
        __style=${FAST_THEME_NAME}command
    } || {
        # Check for command terminator
        [[ "$__arg_type" = 3 ]] && return 2

        # Pass through redirections and here-strings
        if (( in_redirection > 0 || this_word & 128 )) || [[ $__wrd == "<<<" ]]; then
            return 1
        fi

        # --- Flag arguments (no = sign) ---
        if [[ "$__wrd" = --* && "$__wrd" != *=* ]]; then
            __style=${FAST_THEME_NAME}double-hyphen-option
        elif [[ "$__wrd" = -[a-zA-Z]* && "$__wrd" != *=* ]]; then
            __style=${FAST_THEME_NAME}single-hyphen-option
        else
            # --- Hydra override: [~|+|++]key[=value] ---
            local _tok="$__wrd"
            integer _off=0

            # 1. Prefix operators
            if [[ "$_tok" = '~'* ]]; then
                _hydra_hl 0 1 precommand
                (( _off=1 )); _tok="${_tok:1}"
            elif [[ "$_tok" = '++'* ]]; then
                _hydra_hl 0 2 precommand
                (( _off=2 )); _tok="${_tok:2}"
            elif [[ "$_tok" = '+'* ]]; then
                _hydra_hl 0 1 precommand
                (( _off=1 )); _tok="${_tok:1}"
            fi

            # 2. Split on first = (key vs value)
            if [[ "$_tok" = *=* ]]; then
                local _key="${_tok%%=*}"
                local _val="${_tok#*=}"
                integer _klen=${#_key}

                # Highlight key — detect @ package routing
                if [[ "$_key" = *@* ]]; then
                    local _kpath="${_key%%@*}"
                    local _kpkg="${_key#*@}"
                    integer _plen=${#_kpath}
                    _hydra_hl $_off $(( _off + _plen )) assign
                    _hydra_hl $(( _off + _plen )) $(( _off + _plen + 1 )) for-loop-operator
                    (( ${#_kpkg} > 0 )) && \
                        _hydra_hl $(( _off + _plen + 1 )) $(( _off + _klen )) globbing
                else
                    _hydra_hl $_off $(( _off + _klen )) assign
                fi

                # Highlight =
                _hydra_hl $(( _off + _klen )) $(( _off + _klen + 1 )) for-loop-separator

                # Highlight value
                _hydra_hl_value "$_val" $(( _off + _klen + 1 ))
            else
                # No = sign (e.g. ~key for bare delete)
                _hydra_hl $_off $(( _off + ${#_tok} )) assign
            fi

            __style=""
        fi
    }

    # Add highlight for simple single-style cases
    [[ -n "$__style" ]] && \
        (( __start=__start_pos-${#PREBUFFER}, __end=__end_pos-${#PREBUFFER}, __start >= 0 )) && \
        reply+=("$__start $__end ${FAST_HIGHLIGHT_STYLES[$__style]}")

    (( this_word = next_word ))
    _start_pos=$_end_pos

    return 0
}

# vim:ft=zsh:et:sw=4
