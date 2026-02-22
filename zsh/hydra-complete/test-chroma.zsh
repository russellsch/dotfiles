#!/usr/bin/env zsh
# Test suite for chroma-hydra-override.ch
# Run: zsh zsh/hydra-complete/test-chroma.zsh

emulate -L zsh
setopt extended_glob

# --- Source the chroma ---
source "${0:A:h}/chroma-hydra-override.ch" || { print "BAIL OUT! Cannot source chroma"; exit 1 }

# --- Mock globals ---
FAST_THEME_NAME=""
typeset -gA FAST_HIGHLIGHT_STYLES
# Identity map: style name → style name (so we can assert on readable names)
for _s in command precommand assign for-loop-separator for-loop-operator \
          for-loop-number globbing reserved-word single-quoted-argument \
          double-quoted-argument back-or-dollar-double-quoted-argument \
          builtin subtle-separator double-hyphen-option single-hyphen-option; do
    FAST_HIGHLIGHT_STYLES[$_s]=$_s
done
typeset -gA FAST_HIGHLIGHT
PREBUFFER=""

# --- Counters ---
integer _pass=0 _fail=0 _total=0

# --- Assertion helper ---
# Usage: _assert_reply "test name" "expected1" "expected2" ...
_assert_reply() {
    local _name="$1"; shift
    local -a _expected=("$@")
    (( _total++ ))

    if (( ${#reply} != ${#_expected} )); then
        (( _fail++ ))
        print "not ok $_total - $_name (count: expected ${#_expected}, got ${#reply})"
        print "#   expected: (${(j:, :)_expected[@]})"
        print "#   actual:   (${(j:, :)reply[@]})"
        return 1
    fi

    local _i
    for (( _i=1; _i <= ${#_expected}; _i++ )); do
        if [[ "${reply[$_i]}" != "${_expected[$_i]}" ]]; then
            (( _fail++ ))
            print "not ok $_total - $_name (element $_i mismatch)"
            print "#   expected[$_i]: ${_expected[$_i]}"
            print "#   actual[$_i]:   ${reply[$_i]}"
            return 1
        fi
    done

    (( _pass++ ))
    print "ok $_total - $_name"
    return 0
}

# --- Reset helper ---
_reset() {
    reply=()
    __start_pos=0
    # Clear chroma state
    local _k
    for _k in ${(k)FAST_HIGHLIGHT}; do
        [[ "$_k" = chroma-* ]] && unset "FAST_HIGHLIGHT[$_k]"
    done
}

# =============================================
# Helper unit tests
# =============================================

# --- _hydra_hl_value: keywords ---
_reset; _hydra_hl_value "true" 0
_assert_reply "value: true → reserved-word" "0 4 reserved-word"

_reset; _hydra_hl_value "false" 0
_assert_reply "value: false → reserved-word" "0 5 reserved-word"

_reset; _hydra_hl_value "null" 0
_assert_reply "value: null → reserved-word" "0 4 reserved-word"

_reset; _hydra_hl_value "TRUE" 0
_assert_reply "value: TRUE (case-insensitive) → reserved-word" "0 4 reserved-word"

_reset; _hydra_hl_value "False" 0
_assert_reply "value: False (mixed case) → reserved-word" "0 5 reserved-word"

_reset; _hydra_hl_value "inf" 0
_assert_reply "value: inf → reserved-word" "0 3 reserved-word"

_reset; _hydra_hl_value "nan" 0
_assert_reply "value: nan → reserved-word" "0 3 reserved-word"

_reset; _hydra_hl_value "-inf" 0
_assert_reply "value: -inf → reserved-word" "0 4 reserved-word"

_reset; _hydra_hl_value "+inf" 0
_assert_reply "value: +inf → reserved-word" "0 4 reserved-word"

# --- _hydra_hl_value: integers ---
_reset; _hydra_hl_value "42" 0
_assert_reply "value: 42 → number" "0 2 for-loop-number"

_reset; _hydra_hl_value "-7" 0
_assert_reply "value: -7 → number" "0 2 for-loop-number"

_reset; _hydra_hl_value "+3" 0
_assert_reply "value: +3 → number" "0 2 for-loop-number"

_reset; _hydra_hl_value "0" 0
_assert_reply "value: 0 → number" "0 1 for-loop-number"

# --- _hydra_hl_value: floats ---
_reset; _hydra_hl_value "3.14" 0
_assert_reply "value: 3.14 → number" "0 4 for-loop-number"

_reset; _hydra_hl_value "1e-3" 0
_assert_reply "value: 1e-3 → number" "0 4 for-loop-number"

_reset; _hydra_hl_value "+2.5" 0
_assert_reply "value: +2.5 → number" "0 4 for-loop-number"

_reset; _hydra_hl_value "1." 0
_assert_reply "value: 1. (trailing dot) → number" "0 2 for-loop-number"

_reset; _hydra_hl_value "1.5e3" 0
_assert_reply "value: 1.5e3 → number (float with dot+exp)" "0 5 for-loop-number"

_reset; _hydra_hl_value "1.2.3.4e5" 0
_assert_reply "value: 1.2.3.4e5 → not a number (multi-dot rejected)"

# --- _hydra_hl_value: quoted strings ---
_reset; _hydra_hl_value "'hello'" 0
_assert_reply "value: 'hello' → single-quoted" "0 7 single-quoted-argument"

_reset; _hydra_hl_value '"world"' 0
_assert_reply 'value: "world" → double-quoted' "0 7 double-quoted-argument"

# --- _hydra_hl_value: standalone interpolation ---
_reset; _hydra_hl_value '${oc.env:HOME}' 0
_assert_reply 'value: ${oc.env:HOME} → interpolation' "0 14 back-or-dollar-double-quoted-argument"

# --- _hydra_hl_value: function call ---
_reset; _hydra_hl_value "choice(1,2,3)" 0
_assert_reply "value: choice(1,2,3) → function" \
    "0 6 builtin" \
    "6 7 subtle-separator" \
    "12 13 subtle-separator" \
    "7 8 for-loop-number" "8 9 subtle-separator" \
    "9 10 for-loop-number" "10 11 subtle-separator" \
    "11 12 for-loop-number"

# --- _hydra_hl_value: list literal ---
_reset; _hydra_hl_value "[1,2,3]" 0
_assert_reply "value: [1,2,3] → list" \
    "0 1 subtle-separator" \
    "6 7 subtle-separator" \
    "1 2 for-loop-number" "2 3 subtle-separator" \
    "3 4 for-loop-number" "4 5 subtle-separator" \
    "5 6 for-loop-number"

# --- _hydra_hl_value: dict literal ---
_reset; _hydra_hl_value "{a:1,b:2}" 0
_assert_reply "value: {a:1,b:2} → dict" \
    "0 1 subtle-separator" \
    "8 9 subtle-separator" \
    "1 2 assign" "2 3 subtle-separator" "3 4 for-loop-number" \
    "4 5 subtle-separator" \
    "5 6 assign" "6 7 subtle-separator" "7 8 for-loop-number"

# --- _hydra_hl_value: comma sweep ---
_reset; _hydra_hl_value "a,b" 0
_assert_reply "value: a,b → arglist" \
    "1 2 subtle-separator"
# 'a' and 'b' are plain unquoted with no interpolations → no entries for them

# --- _hydra_hl_value: empty ---
_reset; _hydra_hl_value "" 0
_assert_reply "value: empty → no highlights"

# --- _hydra_hl_unquoted: embedded interpolations ---
_reset; _hydra_hl_unquoted 'hello${VAR}world' 0
_assert_reply 'unquoted: hello${VAR}world → one interpolation' \
    "5 11 back-or-dollar-double-quoted-argument"

_reset; _hydra_hl_unquoted '${A}${B}' 0
_assert_reply 'unquoted: ${A}${B} → two interpolations' \
    "0 4 back-or-dollar-double-quoted-argument" \
    "4 8 back-or-dollar-double-quoted-argument"

_reset; _hydra_hl_unquoted 'plain' 0
_assert_reply "unquoted: plain → no interpolations"

# --- _hydra_hl_arglist: basic ---
_reset; _hydra_hl_arglist "a,b" 0
_assert_reply "arglist: a,b → comma" \
    "1 2 subtle-separator"

# --- _hydra_hl_arglist: named arg ---
_reset; _hydra_hl_arglist "name=val,other" 0
_assert_reply "arglist: name=val,other" \
    "0 4 assign" "4 5 for-loop-separator" \
    "8 9 subtle-separator"
# 'val' is unquoted no interp, 'other' is unquoted no interp → no entries

# --- _hydra_hl_arglist: nested parens not split ---
_reset; _hydra_hl_arglist "choice(1,2),3" 0
_assert_reply "arglist: choice(1,2),3 → split at outer comma only" \
    "0 6 builtin" "6 7 subtle-separator" "10 11 subtle-separator" \
    "7 8 for-loop-number" "8 9 subtle-separator" "9 10 for-loop-number" \
    "11 12 subtle-separator" \
    "12 13 for-loop-number"

# --- _hydra_hl_dict ---
_reset; _hydra_hl_dict "x:10,y:20" 0
_assert_reply "dict: x:10,y:20" \
    "0 1 assign" "1 2 subtle-separator" "2 4 for-loop-number" \
    "4 5 subtle-separator" \
    "5 6 assign" "6 7 subtle-separator" "7 9 for-loop-number"

# --- _hydra_hl_maybe_named ---
_reset; _hydra_hl_maybe_named "key=true" 0
_assert_reply "maybe_named: key=true" \
    "0 3 assign" "3 4 for-loop-separator" "4 8 reserved-word"

_reset; _hydra_hl_maybe_named "42" 0
_assert_reply "maybe_named: 42 (plain value)" "0 2 for-loop-number"

# =============================================
# Main chroma function tests
# =============================================

# Helper to invoke chroma/-hydra-override with proper environment
_run_chroma() {
    local __first_call="$1" __wrd="$2"
    integer __start_pos="$3" __end_pos="$4"
    integer __arg_type="${5:-0}"
    integer in_redirection="${6:-0}"
    integer this_word=0 next_word=0
    local active_command="myapp"

    chroma/-hydra-override "$__first_call" "$__wrd" "$__start_pos" "$__end_pos"
    _rc=$?
}

# --- first call: command name ---
_reset
_run_chroma 1 "myapp" 0 5
_assert_reply "chroma: first call → command" "0 5 command"

# --- key=value override ---
_reset
_run_chroma 0 "db.host=localhost" 0 17
_assert_reply "chroma: db.host=localhost" \
    "0 7 assign" "7 8 for-loop-separator"
# 'localhost' is unquoted with no interp → no entry

# --- key=number ---
_reset
_run_chroma 0 "lr=0.001" 0 8
_assert_reply "chroma: lr=0.001" \
    "0 2 assign" "2 3 for-loop-separator" "3 8 for-loop-number"

# --- key=true ---
_reset
_run_chroma 0 "flag=true" 0 9
_assert_reply "chroma: flag=true" \
    "0 4 assign" "4 5 for-loop-separator" "5 9 reserved-word"

# --- prefix +key=value ---
_reset
_run_chroma 0 "+db=true" 0 8
_assert_reply "chroma: +db=true" \
    "0 1 precommand" "1 3 assign" "3 4 for-loop-separator" "4 8 reserved-word"

# --- prefix ++key=value ---
_reset
_run_chroma 0 "++db.host=x" 0 11
_assert_reply "chroma: ++db.host=x" \
    "0 2 precommand" "2 9 assign" "9 10 for-loop-separator"

# --- prefix ~ (bare delete) ---
_reset
_run_chroma 0 "~key" 0 4
_assert_reply "chroma: ~key" \
    "0 1 precommand" "1 4 assign"

# --- @ routing ---
_reset
_run_chroma 0 "group@pkg=val" 0 13
_assert_reply "chroma: group@pkg=val" \
    "0 5 assign" "5 6 for-loop-operator" "6 9 globbing" \
    "9 10 for-loop-separator"

# --- double-hyphen flag ---
_reset
_run_chroma 0 "--multirun" 0 10
_assert_reply "chroma: --multirun → double-hyphen-option" "0 10 double-hyphen-option"

# --- single-hyphen flag ---
_reset
_run_chroma 0 "-m" 0 2
_assert_reply "chroma: -m → single-hyphen-option" "0 2 single-hyphen-option"

# --- flag with = is NOT treated as flag ---
_reset
_run_chroma 0 "--key=val" 0 9
_assert_reply "chroma: --key=val → override, not flag" \
    "0 5 assign" "5 6 for-loop-separator"

# --- command terminator returns 2 ---
_reset
_run_chroma 0 ";" 0 1 3 0
(( _total++ ))
if (( _rc == 2 )); then
    (( _pass++ )); print "ok $_total - chroma: ; with arg_type=3 → rc=2"
else
    (( _fail++ )); print "not ok $_total - chroma: ; with arg_type=3 → expected rc=2, got $_rc"
fi

# --- redirection returns 1 ---
_reset
_run_chroma 0 ">" 0 1 0 1
(( _total++ ))
if (( _rc == 1 )); then
    (( _pass++ )); print "ok $_total - chroma: > with in_redirection=1 → rc=1"
else
    (( _fail++ )); print "not ok $_total - chroma: > with in_redirection=1 → expected rc=1, got $_rc"
fi

# --- offset: value highlighting respects __start_pos ---
_reset
__start_pos=5
_hydra_hl_value "42" 0
_assert_reply "value with __start_pos=5: 42 → offset positions" "5 7 for-loop-number"

# =============================================
# Summary
# =============================================
print ""
print "# $_pass/$_total passed, $_fail failed"
(( _fail == 0 )) && exit 0 || exit 1
