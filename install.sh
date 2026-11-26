#!/usr/bin/env bash
# quartz installer: sets quartz up step by step and says what each step does.
#
#   ./install.sh              set quartz up (asks before it changes anything)
#   ./install.sh --dry-run    show every step, change nothing
#   ./install.sh --yes        no questions: take the default answer each time
#   ./install.sh --uninstall  remove the quartz link and the Hyprland block
#
# Safe to run again: it only does what isn't done yet, and backs up any file it
# edits first. Knobs for testing it (nobody needs them for a normal install):
#   QUARTZ_SKIP_PACKAGES=1   show sudo / pacman / AUR-helper / systemctl commands instead of running them
#   QUARTZ_SKIP_DOWNLOADS=1  show font downloads instead of doing them
#   QUARTZ_TEST_ROOT=<dir>   read /sys, /proc, /usr/lib/dri and glvnd files from <dir> (hardware detection)
#   QUARTZ_TEST_LSPCI=<file> use this lspci output for the graphics chip names
set -u # no pipefail: `… | grep -q` would read as a failure when grep stops early

usage() {
	cat <<'EOF'
quartz installer

  ./install.sh [--dry-run] [--yes]
  ./install.sh --uninstall [--dry-run] [--yes]
  ./install.sh --reinstall [--dry-run] [--yes]

It checks what quartz needs and installs what's missing, sets up its clean
Hyprland config (or adds quartz to yours), its terminal and shell (Ghostty,
zsh, starship), sound and Bluetooth, the fonts, the cursor and some
wallpapers, then starts quartz. Where you already have a config it asks before
replacing it (default: keep yours). It asks before every change and is safe to
run again.

  -n, --dry-run    show every step and command, change nothing
  -y, --yes        don't ask: take the default answer every time
      --uninstall  undo everything this installer did: its configs, links,
                   fonts, cursor, wallpapers, settings and caches go, the
                   configs it replaced come back, and it offers to remove the
                   packages it installed
      --reinstall  --uninstall (keeping the packages), then install again
  -h, --help       show this help
EOF
}

dry=0 yes=0 mode=install
for a in "$@"; do
	case $a in
		-n | --dry-run) dry=1 ;;
		-y | --yes) yes=1 ;;
		--uninstall) mode=uninstall ;;
		--reinstall) mode=reinstall ;;
		-h | --help) usage; exit 0 ;;
		*) printf 'Unknown option: %s\n\n' "$a" >&2; usage >&2; exit 2 ;;
	esac
done

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
cfg_home=${XDG_CONFIG_HOME:-$HOME/.config}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
qs_link=$cfg_home/quickshell/quartz
hypr_dir=$cfg_home/hypr
state_dir=$HOME/.local/state/quartz # where shell/core/Config.qml keeps its settings
cache_dir=$HOME/.cache/quartz        # palettes, thumbnails (Theme.qml)
manifest=$state_dir/installed        # everything this installer added, for --uninstall
hypr_clean=$here/config/hypr/hyprland.lua
clean_mark='-- quartz: clean Hyprland config'
cursor_theme=Bibata-Modern-Ice # quartz's cursor, shipped in cursors/
cursor_tar=$here/cursors/$cursor_theme.tar.gz
root=${QUARTZ_TEST_ROOT:-}
stamp=$(date +%Y%m%d-%H%M%S)
MESA_EGL=/usr/share/glvnd/egl_vendor.d/50_mesa.json
NVIDIA_EGL=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

# ── output ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	G=$'\e[32m' R=$'\e[31m' C=$'\e[36m' Y=$'\e[33m' D=$'\e[2m' B=$'\e[1m' N=$'\e[0m'
else
	G="" R="" C="" Y="" D="" B="" N=""
fi
problems=0
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; problems=$((problems + 1)); }
act()  { printf '  %s→%s %s\n' "$C" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
note() { printf '    %s%s%s\n' "$D" "$*" "$N"; }
say()  { printf '%s\n' "$*"; }
step_n=0 step_total=9
step() { step_n=$((step_n + 1)); printf '\n%s[%d/%d] %s%s\n' "$B" "$step_n" "$step_total" "$*" "$N"; }
pretty() { case $1 in "$HOME") printf '~' ;; "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
# a command line as you would type it
shq() {
	local out="" a
	for a in "$@"; do
		if [[ $a =~ ^[A-Za-z0-9_@%+=:,./-]+$ ]]; then out+="$a "; else out+="'${a//\'/\'\\\'\'}' "; fi
	done
	printf '%s' "${out% }"
}

# ── questions ───────────────────────────────────────────────────────────────
tty_ok() { { : </dev/tty; } 2>/dev/null; }
auto() { # no questions possible: say so once
	if [ $yes -eq 0 ] && [ -z "${told_notty:-}" ]; then
		told_notty=1
		warn "No terminal to answer on, so every question takes its default answer."
	fi
}
# ask "question" y|n → succeeds for yes
ask() {
	local q=$1 def=$2 hint a
	if [ "$def" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi
	if [ $yes -eq 1 ] || ! tty_ok; then
		auto
		printf '  %s?%s %s %s %s\n' "$B" "$N" "$q" "$hint" "$([ "$def" = y ] && echo yes || echo no)"
		[ "$def" = y ]
		return
	fi
	while :; do
		printf '  %s?%s %s %s ' "$B" "$N" "$q" "$hint"
		IFS= read -r a </dev/tty || a=""
		case ${a,,} in
			"") [ "$def" = y ]; return ;;
			y | yes) return 0 ;;
			n | no) return 1 ;;
			*) note "Type y or n, or press Enter for the default." ;;
		esac
	done
}
# ask_ynp "question" → 0 yes, 1 no, 2 print it (default yes)
ask_ynp() {
	local a
	if [ $yes -eq 1 ] || ! tty_ok; then
		auto
		printf '  %s?%s %s [Y/n/p = just print it] yes\n' "$B" "$N" "$1"
		return 0
	fi
	while :; do
		printf '  %s?%s %s [Y/n/p = just print it] ' "$B" "$N" "$1"
		IFS= read -r a </dev/tty || a=""
		case ${a,,} in
			"" | y | yes) return 0 ;;
			n | no) return 1 ;;
			p | print) return 2 ;;
			*) note "Type y, n or p, or press Enter for yes." ;;
		esac
	done
}
# ask_path "question" default → $answer (absolute; ~ and relative = under your home)
ask_path() {
	local a
	if [ $yes -eq 1 ] || ! tty_ok; then
		auto
		printf '  %s?%s %s [%s] %s\n' "$B" "$N" "$1" "$(pretty "$2")" "$(pretty "$2")"
		answer=$2
		return
	fi
	printf '  %s?%s %s [%s] ' "$B" "$N" "$1" "$(pretty "$2")"
	IFS= read -r a </dev/tty || a=""
	[ -z "$a" ] && a=$2
	case $a in
		"~") a=$HOME ;;
		"~/"*) a=$HOME/${a#"~/"} ;;
		/*) ;;
		*) a=$HOME/$a ;;
	esac
	answer=${a%/}
}

# ── doing things (every change goes through these, so --dry-run catches it) ──
run() {
	if [ $dry -eq 1 ]; then act "would run: $(shq "$@")"; return 0; fi
	act "$(shq "$@")"
	"$@"
}
run_q() { # like run, without the command's own output
	if [ $dry -eq 1 ]; then act "would run: $(shq "$@")"; return 0; fi
	act "$(shq "$@")"
	"$@" >/dev/null
}
sys_run() { # package managers, sudo, systemctl
	if [ $dry -eq 0 ] && [ "${QUARTZ_SKIP_PACKAGES:-0}" = 1 ]; then
		act "skipped (QUARTZ_SKIP_PACKAGES): $(shq "$@")"
		return 0
	fi
	run "$@"
}
backup() { # file → a copy next to it
	local b="$1.quartz-backup-$stamp"
	if [ $dry -eq 1 ]; then act "would back up $(pretty "$1") to $(pretty "$b")"; return 0; fi
	cp -pL -- "$1" "$b" && rec file "$b" && ok "Backed up $(pretty "$1") to $(pretty "$b")"
}
# rec kind path [path2] → note what this installer did, so --uninstall can undo it:
#   file / link / dir (made here), backup <path> <moved-aside copy>, pkg / syspkg <name>, shell <old login shell>
rec() {
	[ $dry -eq 1 ] && return 0
	mkdir -p "$state_dir" && (IFS=$'\t'; printf '%s\n' "$*") >>"$manifest"
}
recorded() { [ -f "$manifest" ] && grep -qxF -- "$(IFS=$'\t'; printf '%s' "$*")" "$manifest"; }
# aside path → move a file of yours out of the way (it comes back with --uninstall)
aside() {
	local b="$1.quartz-backup-$stamp"
	run mv -- "$1" "$b" && rec backup "$1" "$b" && [ $dry -eq 0 ] && ok "Moved yours aside: $(pretty "$b")"
	return 0
}
# place_config src dest "what" → one of quartz's configs at dest. Where one is
# there already, ask first (default: keep yours). Succeeds when quartz's is in place.
place_config() {
	local src=$1 dest=$2 what=$3
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		if cmp -s -- "$src" "$dest"; then ok "$what: quartz's ($(pretty "$dest"))"; return 0; fi
		if recorded file "$dest"; then
			act "quartz's $what has changed since you installed it ($(pretty "$dest"))."
			ask "Update it? (the old one is moved aside)" y || { ok "Kept the one you have."; return 0; }
		else
			act "You already have $what: $(pretty "$dest")"
			ask "Replace it with quartz's? (yours is moved aside; --uninstall brings it back)" n || { ok "Kept yours."; return 1; }
		fi
		aside "$dest"
	fi
	run mkdir -p "$(dirname "$dest")" && run cp -- "$src" "$dest" && rec file "$dest" && [ $dry -eq 0 ] && ok "$what: $(pretty "$dest")"
	return 0
}

# ── facts ───────────────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }
in_list() { local x n=$1; shift; for x in "$@"; do [ "$x" = "$n" ] && return 0; done; return 1; }
hypr_running() { [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl && hyprctl -j version >/dev/null 2>&1; }
# Is the running Hyprland using the config folder this installer looks at?
# (Not when you try the installer with another HOME.) Can't tell → yes.
hypr_ours() {
	local pid env cfg
	pid=$(pgrep -o -x Hyprland 2>/dev/null) || return 0
	env=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null) || return 0
	cfg=$(sed -n 's/^XDG_CONFIG_HOME=//p' <<<"$env")
	[ -z "$cfg" ] && cfg=$(sed -n 's/^HOME=//p' <<<"$env")/.config
	[ "$(readlink -f "$cfg/hypr")" = "$(readlink -f "$hypr_dir")" ]
}
hypr_live() { hypr_running && hypr_ours; }
quartz_running() { pgrep -f '^([^ ]*/)?(qs|quickshell)( .*)? -c quartz( |$)' >/dev/null 2>&1; }
font_ok() { have fc-list && fc-list : family 2>/dev/null | tr ',' '\n' | grep -qixF -- "$1"; }
have_bluez() { have bluetoothd || [ -x /usr/lib/bluetooth/bluetoothd ] || [ -x /usr/libexec/bluetooth/bluetoothd ]; }

is_arch=0
if have pacman && [ -r /etc/os-release ]; then
	case " $(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}") " in *" arch "*) is_arch=1 ;; esac
fi
aur_helper=""
for h in yay paru; do have "$h" && { aur_helper=$h; break; }; done

# ── Hyprland config ─────────────────────────────────────────────────────────
start_re='^[[:space:]]*(--|#) >>> quartz >>>[[:space:]]*$'
end_re='^[[:space:]]*(--|#) <<< quartz <<<[[:space:]]*$'
hypr_lua=$hypr_dir/hyprland.lua
hypr_conf=$hypr_dir/hyprland.conf
detect_hypr() {
	if [ -f "$hypr_lua" ]; then hypr_mode=lua hypr_file=$hypr_lua
	elif [ -f "$hypr_conf" ]; then hypr_mode=classic hypr_file=$hypr_conf
	else hypr_mode=none hypr_file=$hypr_lua
	fi
}
detect_hypr
is_clean() { [ -f "$1" ] && head -n1 "$1" | grep -qF -- "$clean_mark"; }
# the file without quartz's block and trailing blank lines
outside_block() {
	awk -v s="$start_re" -v e="$end_re" '$0 ~ s { skip = 1 } !skip { l[++n] = $0 } skip && $0 ~ e { skip = 0 }
		END { while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' "$1"
}
ext_of() { [ "$1" = lua ] && echo lua || echo conf; }

# none | ok | broken
block_state() {
	[ -f "$1" ] || { echo none; return; }
	local s e
	s=$(grep -cE "$start_re" "$1")
	e=$(grep -cE "$end_re" "$1")
	if [ "$s" = 0 ] && [ "$e" = 0 ]; then echo none
	elif [ "$s" = 1 ] && [ "$e" = 1 ] && [ "$(grep -nE "$start_re" "$1" | cut -d: -f1)" -lt "$(grep -nE "$end_re" "$1" | cut -d: -f1)" ]; then echo ok
	else echo broken
	fi
}
block_text() { awk -v s="$start_re" -v e="$end_re" '$0 ~ s { f = 1 } f { print } $0 ~ e { f = 0 }' "$1"; }

# Your own Hyprland config: every *.lua / *.conf under the hypr folder, without
# quartz's block, comment lines or our backups, as "file:line:text".
user_cfg() {
	local ext=$1 cm f
	[ "$ext" = lua ] && cm="--" || cm="#"
	[ -d "$hypr_dir" ] || return 0
	while IFS= read -r -d '' f; do
		awk -v f="$f" -v cm="$cm" -v s="$start_re" -v e="$end_re" '
			$0 ~ s { skip = 1 }
			!skip { t = $0; sub(/^[[:space:]]+/, "", t); if (substr(t, 1, length(cm)) != cm) print f ":" FNR ":" $0 }
			$0 ~ e { skip = 0 }' "$f"
	done < <(find -L "$hypr_dir" -maxdepth 4 -type f -name "*.$ext" ! -name '*.quartz-backup-*' -print0 2>/dev/null)
}
user_sets() { # VAR → your config already sets this environment variable
	if [ "$hypr_mode" = classic ]; then
		user_cfg conf | grep -qE "^[^:]*:[0-9]+:[[:space:]]*env[[:space:]]*=[[:space:]]*$1[[:space:]]*,"
	else
		user_cfg lua | grep -qE "hl\.env\([[:space:]]*[\"']$1[\"']"
	fi
}
scan_hypr() {
	local ext
	ext=$(ext_of "$hypr_mode")
	elsewhere=$(user_cfg "$ext" | grep -E 'quartz\.lua|quartz:[A-Za-z]|(qs|quickshell)( [^ ]+)* -c quartz' | head -3)
	user_clip=0
	user_cfg "$ext" | grep -q 'cliphist store' && user_clip=1
}

# "SUPER + SHIFT + C" → "65 c" (Hyprland's modmask and key)
key_mask() {
	local s=${1// /} m=0 t k
	local -a parts
	IFS=+ read -ra parts <<<"$s"
	k=${parts[${#parts[@]} - 1]}
	for t in "${parts[@]:0:${#parts[@]}-1}"; do
		case ${t^^} in
			SUPER | WIN | LOGO | MOD4 | META) m=$((m | 64)) ;;
			SHIFT) m=$((m | 1)) ;;
			CTRL | CONTROL) m=$((m | 4)) ;;
			ALT | MOD1) m=$((m | 8)) ;;
		esac
	done
	printf '%s %s' "$m" "${k,,}"
}
pretty_key() { local k=${1//SUPER/Super}; printf '%s' "${k//SHIFT/Shift}"; }

# The classic-config binds: key|line|what it does (the Lua module has its own)
classic_binds() {
	cat <<'EOF'
SUPER + SPACE|bind = SUPER, SPACE, global, quartz:launcher|app launcher
SUPER + V|bind = SUPER, V, global, quartz:clipboard|clipboard history
SUPER + ESCAPE|bind = SUPER, ESCAPE, global, quartz:power|power menu
SUPER + A|bind = SUPER, A, global, quartz:control|control centre
SUPER + N|bind = SUPER, N, global, quartz:control|notifications
SUPER + SHIFT + N|bind = SUPER SHIFT, N, global, quartz:dnd|do not disturb
SUPER + SHIFT + W|bind = SUPER SHIFT, W, global, quartz:wifi|Wi-Fi
SUPER + B|bind = SUPER, B, global, quartz:bluetooth|Bluetooth
SUPER + SHIFT + A|bind = SUPER SHIFT, A, global, quartz:sound|sound devices and apps
SUPER + D|bind = SUPER, D, global, quartz:calendar|calendar
SUPER + M|bind = SUPER, M, global, quartz:media|now playing
SUPER + COMMA|bind = SUPER, COMMA, global, quartz:settings|settings
SUPER + SLASH|bind = SUPER, SLASH, global, quartz:help|keyboard cheatsheet
SUPER + C|bind = SUPER, C, global, quartz:wallpapers|wallpaper picker
SUPER + SHIFT + C|bind = SUPER SHIFT, C, global, quartz:randomWallpaper|random wallpaper
SUPER + L|bind = SUPER, L, exec, loginctl lock-session|lock
XF86AudioPlay|bindl = , XF86AudioPlay, global, quartz:mediaToggle|play / pause
XF86AudioNext|bindl = , XF86AudioNext, global, quartz:mediaNext|next track
XF86AudioPrev|bindl = , XF86AudioPrev, global, quartz:mediaPrev|previous track
XF86MonBrightnessUp|bindel = , XF86MonBrightnessUp, exec, qs -c quartz ipc call quartz brightness 5|brightness up
XF86MonBrightnessDown|bindel = , XF86MonBrightnessDown, exec, qs -c quartz ipc call quartz brightness -- -5|brightness down
EOF
}
# every key quartz binds: key|what it does
quartz_keys() {
	if [ "$hypr_mode" = classic ]; then
		classic_binds | awk -F'|' '{ print $1 "|" $3 }'
		return
	fi
	local line key label re='^[[:space:]]*bind\((mod \.\. )?"([^"]+)"'
	while IFS= read -r line; do
		[[ $line =~ $re ]] || continue
		key=${BASH_REMATCH[2]}
		[ -n "${BASH_REMATCH[1]}" ] && key="SUPER$key"
		label=""
		[[ $line == *" -- "* ]] && label=${line##*-- }
		printf '%s|%s\n' "$key" "${label%% (*}"
	done <"$here/hypr/quartz.lua"
}

# Binds Hyprland has right now (default submap): "modmask<TAB>key<TAB>action"
live_binds() {
	hyprctl binds -j 2>/dev/null | awk '
		function val(s) { sub(/^[^:]*:[[:space:]]*"?/, "", s); sub(/"?,?[[:space:]]*$/, "", s); return s }
		/"modmask":/    { m = val($0) }
		/"submap":/     { sm = val($0) }
		/"key":/        { k = tolower(val($0)) }
		/"dispatcher":/ { d = val($0); sub(/^HL\.Dispatcher\(/, "", d); sub(/\)$/, "", d) }
		/^[[:space:]]*}/ { if (sm == "" && k != "") print m "\t" k "\t" d; m = k = d = sm = "" }'
}
# The same, read from your config files (Hyprland isn't running). Catches the
# usual `hl.bind(mainMod .. " + C", …)` / `bind = $mainMod, C, …` forms.
static_binds() {
	local text var val expr mods key
	if [ "$hypr_mode" = classic ]; then
		text=$(user_cfg conf | cut -d: -f3-)
		declare -A vars=()
		while IFS='=' read -r var val; do vars[$var]=$val; done < <(sed -nE 's/^[[:space:]]*\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*([^#]*[^#[:space:]]).*/\1=\2/p' <<<"$text")
		while IFS='|' read -r mods key; do
			for var in "${!vars[@]}"; do mods=${mods//\$$var/${vars[$var]}}; done
			mods=$(printf '%s' "$mods" | tr -s ' _' '++')
			printf '%s\t?\n' "$(key_mask "${mods:+$mods+}$key" | tr ' ' '\t')"
		done < <(sed -nE 's/^[[:space:]]*bind[a-z]*[[:space:]]*=[[:space:]]*([^,]*),[[:space:]]*([^,[:space:]]+)[[:space:]]*,.*/\1|\2/p' <<<"$text")
	else
		text=$(user_cfg lua | cut -d: -f3-)
		declare -A vars=()
		while IFS='=' read -r var val; do vars[$var]=$val; done < <(sed -nE 's/^[[:space:]]*(local[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*"([A-Z +]+)".*/\2=\3/p' <<<"$text")
		while IFS= read -r expr; do
			for var in "${!vars[@]}"; do expr=${expr//$var .. \"/\"${vars[$var]}}; done
			[[ $expr == *..* ]] && continue # built from something we can't read
			expr=${expr//\"/}
			printf '%s\t?\n' "$(key_mask "$expr" | tr ' ' '\t')"
		done < <(grep -oE 'hl\.bind\([^,]+' <<<"$text" | sed 's/^hl\.bind([[:space:]]*//')
	fi
}

# Which of quartz's keys your config already uses → skip_keys / skip_labels
find_conflicts() {
	skip_keys=() skip_labels=() skip_yours=()
	local binds src old_skip="" key label mm k n own yours why="Hyprland isn't running"
	hypr_running && why="the running Hyprland uses another config folder"
	if hypr_live; then
		src=live binds=$(live_binds)
	elif [ -f "$hypr_file" ]; then
		src=static binds=$(static_binds)
	else
		note "Couldn't check which keys your config already uses (no config and Hyprland isn't running)."
		return
	fi
	[ "$(block_state "$hypr_file")" = ok ] && old_skip=$(block_text "$hypr_file" | grep -i 'skip' | grep -oE '"[^"]+"' | tr -d '"')
	while IFS='|' read -r key label; do
		read -r mm k <<<"$(key_mask "$key")"
		n=$(awk -F'\t' -v m="$mm" -v k="$k" '$1 == m && $2 == k' <<<"$binds" | wc -l)
		own=0
		# Hyprland already runs quartz's block: one of those binds is quartz's own
		if [ $src = live ] && [ "$(block_state "$hypr_file")" = ok ] && ! grep -qxF -- "$key" <<<"$old_skip"; then own=1; fi
		if [ $((n - own)) -gt 0 ]; then
			yours=$(awk -F'\t' -v m="$mm" -v k="$k" '$1 == m && $2 == k && $3 != "global" && $3 != "?" { print $3; exit }' <<<"$binds")
			skip_keys+=("$key") skip_labels+=("$label") skip_yours+=("$yours")
		fi
	done < <(quartz_keys)
	if [ ${#skip_keys[@]} -eq 0 ]; then
		ok "None of quartz's keys clash with yours$([ $src = static ] && echo " (checked your config files: $why)")."
		return
	fi
	# a fresh copy of Hyprland's example: choose_keymap hands these keys to quartz
	[ "$fresh" = 1 ] && [ "$hypr_mode" = lua ] && return
	warn "These keys already do something in your config, so quartz leaves them to you:"
	local i
	for i in "${!skip_keys[@]}"; do
		note "$(printf '%-22s %s' "$(pretty_key "${skip_keys[$i]}")" "${skip_labels[$i]}${skip_yours[$i]:+  (yours: ${skip_yours[$i]})}")"
	done
	note "Pressing one would otherwise do both things at once. To hand a key to quartz,"
	note "remove it from your config and run this installer again."
	[ $src = static ] && note "(Checked your config files because $why; run this again inside Hyprland for an exact check.)"
}

# quartz's full keymap (windows, workspaces, apps, screenshots): on for a
# fresh copy of Hyprland's example, asked otherwise. With it, quartz's keys
# replace the config's binds on the same keys, so nothing is skipped.
choose_keymap() {
	[ "$hypr_mode" = lua ] || return 0
	if [ "$fresh" = 1 ]; then
		keymap=1
		ok "Fresh setup: quartz brings a full keymap (windows, workspaces, apps, screenshots)."
		if [ ${#skip_keys[@]} -gt 0 ]; then
			note "It replaces what Hyprland's example had on these keys:"
			local i
			for i in "${!skip_keys[@]}"; do note "$(printf '%-22s %s' "$(pretty_key "${skip_keys[$i]}")" "${skip_labels[$i]}")"; done
		fi
		skip_keys=()
		return
	fi
	act "quartz also has a full keymap for windows, workspaces, apps and screenshots,"
	note "the one its cheatsheet (Super + /) shows. Using it replaces your own binds"
	note "on the same keys (yours stay in your config, quartz's block just comes last)."
	local had=n
	[ "$(block_state "$hypr_file")" = ok ] && block_text "$hypr_file" | grep -q 'essentials = true' && had=y
	[ $had = y ] && note "Your quartz block uses it now."
	if ask "Use quartz's full keymap?" $had; then
		keymap=1
		skip_keys=()
	fi
}

# ── the block this installer adds ───────────────────────────────────────────
lua_str() { local s=${1//\\/\\\\}; printf '"%s"' "${s//\"/\\\"}"; }
lua_path() {
	local p=$here/hypr/quartz.lua
	if [[ $p == "$HOME"/* ]]; then printf 'os.getenv("HOME") .. %s' "$(lua_str "${p#"$HOME"}")"; else lua_str "$p"; fi
}
qs_start() { # the command that starts quartz
	if [ "${hw_gpu:-0}" = 1 ]; then echo "env __EGL_VENDOR_LIBRARY_FILENAMES=$MESA_EGL __GLX_VENDOR_LIBRARY_NAME=mesa qs -c quartz -d"; else echo "qs -c quartz -d"; fi
}
nv_va() { [ "${hw_nv_env:-0}" = 1 ] && { va_ok nvidia || in_list libva-nvidia-driver "${planned[@]}"; }; }
make_block() {
	local autostart=true clip=true k line
	[ "$user_clip" = 1 ] && clip=false
	if [ "$hypr_mode" = classic ]; then
		echo "# >>> quartz >>>"
		echo "# Added by quartz's install.sh. Run it again to update this block, or"
		echo "# \`install.sh --uninstall\` to remove it. Keep your own settings outside it."
		if [ "${hw_nv_env:-0}" = 1 ]; then
			echo "# NVIDIA: OpenGL and video decoding through the NVIDIA driver"
			nv_va && echo "env = LIBVA_DRIVER_NAME,nvidia"
			echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
			nv_va && echo "env = NVD_BACKEND,direct"
		fi
		if [ "${hw_drm:-0}" = 1 ]; then
			echo "# Hybrid graphics: the first GPU (integrated) renders the desktop."
			echo "# /dev/dri/cardN numbers can change between boots: run install.sh again if they do."
			echo "env = AQ_DRM_DEVICES,$igpu_card:$nv_card"
		fi
		if [ "${use_cursor:-0}" = 1 ]; then
			echo "# Cursor: quartz's $cursor_theme"
			echo "env = XCURSOR_THEME,$cursor_theme"
			echo "env = XCURSOR_SIZE,24"
			echo "env = HYPRCURSOR_THEME,$cursor_theme"
			echo "env = HYPRCURSOR_SIZE,24"
			echo "exec-once = hyprctl setcursor $cursor_theme 24"
			echo "exec-once = gsettings set org.gnome.desktop.interface cursor-theme $cursor_theme"
		fi
		[ $autostart = true ] && echo "exec-once = $(qs_start)"
		if [ $clip = true ]; then
			echo "exec-once = wl-paste --type text --watch cliphist store"
			echo "exec-once = wl-paste --type image --watch cliphist store"
		fi
		classic_binds | while IFS='|' read -r k line _; do in_list "$k" "${skip_keys[@]}" || echo "$line"; done
		if [ ${#skip_keys[@]} -gt 0 ]; then
			printf '# quartz skips keys your config already uses:'
			printf ' "%s"' "${skip_keys[@]}"
			echo
		fi
		echo "# Layer and window rules (no Hyprland animation on quartz-panel/-toast/-osd/-overlay,"
		echo "# blur on quartz-frost, float + centre the window titled \"Settings · quartz\") depend"
		echo "# on your Hyprland version: see \"Classic hyprland.conf\" in quartz's README."
		echo "# <<< quartz <<<"
		return
	fi
	echo "-- >>> quartz >>>"
	echo "-- Added by quartz's install.sh. Run it again to update this block, or"
	echo "-- \`install.sh --uninstall\` to remove it. Keep your own settings outside it."
	if [ "${hw_nv_env:-0}" = 1 ]; then
		echo "-- NVIDIA: OpenGL and video decoding through the NVIDIA driver"
		nv_va && echo 'hl.env("LIBVA_DRIVER_NAME", "nvidia")'
		echo 'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")'
		nv_va && echo 'hl.env("NVD_BACKEND", "direct")'
	fi
	echo "do"
	echo "	local ok, quartz = pcall(dofile, $(lua_path))"
	echo "	if ok then"
	echo "		quartz.setup({"
	echo "			mod = \"SUPER\","
	echo "			autostart = $autostart,"
	echo "			clipboard = $clip,$([ $clip = false ] && echo " -- your config already runs cliphist")"
	[ "${hw_gpu:-0}" = 1 ] && echo "			gpu = \"integrated\", -- quartz runs on the integrated GPU (Mesa)"
	[ "${hw_drm:-0}" = 1 ] && echo "			drm_devices = { \"$igpu_pci\", \"$nv_pci\" }, -- the first one renders the desktop"
	[ "${use_cursor:-0}" = 1 ] && echo "			cursor = \"$cursor_theme\", -- quartz's cursor (white, rounded)"
	if [ "$keymap" = 1 ]; then
		echo "			essentials = true, -- windows, workspaces, apps, screenshots"
		echo "			take_over = true, -- quartz's keys replace earlier binds on the same keys"
	fi
	if [ ${#skip_keys[@]} -gt 0 ]; then
		printf '\t\t\tskip = {'
		printf ' "%s",' "${skip_keys[@]}"
		printf ' }, -- keys your config already uses\n'
	fi
	echo "		})"
	echo "	else"
	echo "		hl.notification.create({ text = \"quartz: couldn't load \" .. tostring(quartz), timeout = 8000 })"
	echo "	end"
	echo "end"
	echo "-- <<< quartz <<<"
}
# put_block file blockfile → replace the marked block in place, or append it
put_block() {
	local file=$1 blk=$2 tmp real
	if [ "$(block_state "$file")" = ok ]; then
		if [ "$(block_text "$file")" = "$(cat "$blk")" ]; then ok "$(pretty "$file") already has quartz's block, up to date."; return 0; fi
		backup "$file"
		if [ $dry -eq 1 ]; then act "would replace quartz's block in $(pretty "$file") with:"; sed 's/^/      /' "$blk"; hypr_changed=1; return 0; fi
		tmp=$(mktemp)
		awk -v s="$start_re" -v e="$end_re" -v blk="$blk" '
			$0 ~ s { while ((getline l < blk) > 0) print l; skip = 1; next }
			skip && $0 ~ e { skip = 0; next }
			!skip { print }' "$file" >"$tmp"
	else
		[ -f "$file" ] && backup "$file"
		if [ $dry -eq 1 ]; then act "would add this to the end of $(pretty "$file"):"; sed 's/^/      /' "$blk"; hypr_changed=1; return 0; fi
		tmp=$(mktemp)
		{
			cat "$file"
			[ -s "$file" ] && [ -n "$(tail -c1 "$file")" ] && echo
			[ -s "$file" ] && echo
			cat "$blk"
		} >"$tmp"
	fi
	# write through a symlink (stowed dotfiles stay links) and keep the file's permissions
	real=$(readlink -f "$file")
	cat "$tmp" >"$real" && rm -f "$tmp" && ok "Updated $(pretty "$file")." && hypr_changed=1
}
remove_block() { # file → take quartz's block (and the blank line before it) out
	local file=$1 tmp real
	if [ $dry -eq 1 ]; then act "would remove quartz's block from $(pretty "$file")"; hypr_changed=1; return 0; fi
	tmp=$(mktemp)
	awk -v s="$start_re" -v e="$end_re" '
		held { if ($0 ~ s) { held = 0; skip = 1; next } print prev; held = 0 }
		skip { if ($0 ~ e) skip = 0; next }
		$0 ~ s { skip = 1; next }
		$0 == "" { prev = $0; held = 1; next }
		{ print }
		END { if (held) print prev }' "$file" >"$tmp"
	real=$(readlink -f "$file")
	cat "$tmp" >"$real" && rm -f "$tmp" && ok "Removed quartz's block from $(pretty "$file")." && hypr_changed=1
}

# ── 1. what quartz needs ────────────────────────────────────────────────────
missing_pkgs=() missing_fonts=() optional_pkgs=()
want() { in_list "$1" "${missing_pkgs[@]}" || missing_pkgs+=("$1"); }
check_deps() { # [quiet: only what's missing | silent: nothing] → missing_count
	local quiet=${1:-} c p why
	missing_pkgs=() missing_fonts=() optional_pkgs=() missing_count=0
	miss() { missing_count=$((missing_count + 1)); [ "$quiet" = silent ] || printf '  %s✗%s %s\n' "$R" "$N" "$*"; }
	while IFS='|' read -r c p why; do
		if { [ "$c" = bluetoothd ] && have_bluez; } || have "$c"; then
			[ -z "$quiet" ] && ok "$c ${D}— $why${N}"
		else
			miss "$c is missing ${D}— $why (package: $p)${N}"
			want "$p"
		fi
	done <<'EOF'
qs|quickshell|Quickshell, which runs quartz
hyprctl|hyprland|Hyprland, the window manager quartz sits on
matugen|matugen|picks quartz's colours from your wallpaper
wl-copy|wl-clipboard|copy and paste
cliphist|cliphist|clipboard history (Super + V)
brightnessctl|brightnessctl|screen brightness
wpctl|wireplumber|volume (PipeWire)
nmcli|networkmanager|Wi-Fi
bluetoothd|bluez|Bluetooth
upower|upower|battery
gdbus|glib2|lock screen
busctl|systemd|lock screen
setpriv|util-linux|lock screen
udevadm|systemd|brightness changes
ffmpeg|ffmpeg|wallpaper thumbnails in the picker
pipewire-pulse|pipewire-pulse|sound for your apps (PipeWire in PulseAudio's place)
hyprshot|hyprshot|screenshots (Super + P, Print, the control centre's button)
hyprsunset|hyprsunset|Night light (Settings › Sound & display)
xdg-open|xdg-utils|opening files, folders and links
ghostty|ghostty|the terminal (Super + T)
zsh|zsh|the shell in it
starship|starship|its prompt
git|git|fetches the shell's plugins
fzf|fzf|fuzzy history and file search in the shell
zoxide|zoxide|cd that learns your folders
eza|eza|ls with icons
EOF
	if have powerprofilesctl; then
		[ -z "$quiet" ] && ok "powerprofilesctl ${D}— Power mode (Settings › Battery)${N}"
	elif have tlp || have auto-cpufreq || have tuned-adm; then
		[ -z "$quiet" ] && note "· Power mode is off: tlp / auto-cpufreq / tuned runs your power here, and power-profiles-daemon would fight it"
	else
		miss "powerprofilesctl is missing ${D}— Power mode (package: power-profiles-daemon)${N}"
		want power-profiles-daemon
	fi
	if have awww; then
		[ -z "$quiet" ] && ok "awww ${D}— draws the wallpaper${N}"
	elif have setwall; then
		[ -z "$quiet" ] && ok "setwall ${D}— no awww, so quartz hands wallpaper changes to setwall${N}"
	else
		miss "awww is missing ${D}— draws the wallpaper (package: awww)${N}"
		want awww
	fi
	for c in "Material Symbols Rounded" "Outfit"; do
		if font_ok "$c"; then
			[ -z "$quiet" ] && ok "font: $c"
		else
			miss "font: $c is missing ${D}— $([ "$c" = Outfit ] && echo "quartz's text" || echo "quartz's icons")${N}"
			missing_fonts+=("$c")
			[ "$c" = "Material Symbols Rounded" ] && want ttf-material-symbols-variable
		fi
	done
}

# ── 2. hardware ─────────────────────────────────────────────────────────────
hw_pkgs=()
hw_want() { in_list "$1" "${hw_pkgs[@]}" || hw_pkgs+=("$1"); }
pick_pkg() { # first of these names your repos have (Arch); else the first
	local p
	if [ $is_arch = 1 ]; then for p in "$@"; do pacman -Si "$p" >/dev/null 2>&1 && { echo "$p"; return; }; done; fi
	echo "$1"
}
va_ok() { # VA-API driver name → its library is installed
	local d
	for d in /usr/lib/dri /usr/lib64/dri /usr/lib/x86_64-linux-gnu/dri /usr/lib/aarch64-linux-gnu/dri; do
		[ -e "$root$d/${1}_drv_video.so" ] && return 0
	done
	return 1
}
gpu_label() { # pci vendor → "AMD Radeon …"
	local line=""
	if [ -n "${QUARTZ_TEST_LSPCI:-}" ]; then line=$(grep -m1 "^${1#0000:} " "$QUARTZ_TEST_LSPCI" 2>/dev/null)
	elif have lspci; then line=$(lspci -s "$1" 2>/dev/null | head -1)
	fi
	line=${line#*: }
	line=$(printf '%s' "$line" | sed -E 's/ \[[0-9a-f]{4}(:[0-9a-f]{4})?\]//g; s/ \(rev [0-9a-f]+\)$//; s/^Advanced Micro Devices, Inc\. \[AMD\/ATI\]/AMD/; s/^NVIDIA Corporation/NVIDIA/; s/^Intel Corporation/Intel/; s/^(AMD|NVIDIA|Intel) [^[]*\[([^]]+)\]$/\1 \2/')
	if [ -n "$line" ]; then echo "$line"; else case $2 in 0x1002) echo "AMD graphics" ;; 0x8086) echo "Intel graphics" ;; 0x10de) echo "NVIDIA graphics" ;; *) echo "graphics chip ($2)" ;; esac; fi
}
detect_gpus() {
	gpu_vendor=() gpu_driver=() gpu_pci=() gpu_boot=() gpu_name=() gpu_card=()
	local d c u
	for d in "$root"/sys/class/drm/card*; do
		c=${d##*/}
		[[ $c =~ ^card[0-9]+$ ]] && [ -r "$d/device/vendor" ] || continue
		u=$(cat "$d/device/uevent" 2>/dev/null)
		[[ $u == *PCI_SLOT_NAME=* ]] || continue # not a PCI graphics chip
		gpu_card+=("/dev/dri/$c")
		gpu_vendor+=("$(cat "$d/device/vendor")")
		gpu_driver+=("$(sed -n 's/^DRIVER=//p' <<<"$u")")
		gpu_pci+=("$(sed -n 's/^PCI_SLOT_NAME=//p' <<<"$u")")
		gpu_boot+=("$(cat "$d/device/boot_vga" 2>/dev/null || echo 0)")
		gpu_name+=("$(gpu_label "${gpu_pci[-1]}" "${gpu_vendor[-1]}")")
	done
}
# a sound device driven (or, unbound, meant to be driven) by Sound Open Firmware.
# Only what's bound counts: the snd_sof modules load on many machines that don't use them.
sof_chip() {
	local d drv
	for d in "$root"/sys/bus/pci/devices/*; do
		case $(cat "$d/class" 2>/dev/null) in 0x0401* | 0x0403*) ;; *) continue ;; esac
		drv=$(basename "$(readlink "$d/driver" 2>/dev/null)")
		case $drv in
			sof-audio-pci* | snd_sof*) return 0 ;;
			"") modprobe -R "$(cat "$d/modalias" 2>/dev/null)" 2>/dev/null | grep -q sof && return 0 ;;
		esac
	done
	return 1
}
hardware() {
	step "Your hardware"
	local i ig=-1 nv=-1
	# laptop speakers and microphones on "Sound Open Firmware" chips stay silent without it
	if sof_chip; then
		local p
		for p in sof-firmware alsa-ucm-conf; do [ $is_arch = 1 ] && ! pacman -Q "$p" >/dev/null 2>&1 && hw_want "$p"; done
		if [ ${#hw_pkgs[@]} -gt 0 ]; then
			act "Your sound chip needs its firmware for the speakers and microphone: ${hw_pkgs[*]}."
		else
			ok "Sound chip firmware (sof-firmware)"
		fi
	fi

	detect_gpus
	if [ ${#gpu_pci[@]} -eq 0 ]; then
		note "Couldn't see a graphics chip in /sys/class/drm, so there's nothing to suggest."
		return
	fi
	for i in "${!gpu_pci[@]}"; do
		case ${gpu_vendor[$i]} in
			0x10de) [ $nv -lt 0 ] && nv=$i ;;
			0x1002 | 0x8086) if [ $ig -lt 0 ] || [ "${gpu_boot[$i]}" = 1 ]; then ig=$i; fi ;;
		esac
	done
	for i in "${!gpu_pci[@]}"; do
		ok "Graphics: ${gpu_name[$i]} ${D}(driver: ${gpu_driver[$i]:-none}, ${gpu_pci[$i]})${N}"
	done

	if [ $nv -ge 0 ] && [ "${gpu_driver[$nv]}" = nvidia ]; then
		local ms
		ms=$(cat "$root/sys/module/nvidia_drm/parameters/modeset" 2>/dev/null)
		if [ "$ms" = Y ]; then
			ok "NVIDIA kernel modesetting is on (Hyprland needs it)"
		else
			bad "NVIDIA kernel modesetting is $([ -z "$ms" ] && echo "unknown (the nvidia_drm module isn't loaded)" || echo off)."
			note "Hyprland needs it to drive screens on the NVIDIA card. Turn it on by adding"
			note "nvidia_drm.modeset=1 to your kernel's boot options, then reboot. The Arch wiki"
			note "page \"NVIDIA\" (section \"DRM kernel mode setting\") shows how for each boot loader."
		fi
	elif [ $nv -ge 0 ]; then
		note "The NVIDIA card uses the open ${gpu_driver[$nv]:-kernel} driver. Hyprland works on it, but slowly;"
		note "most people install NVIDIA's own driver (Arch wiki page \"NVIDIA\")."
	fi

	if [ $nv -ge 0 ] && [ $ig -lt 0 ] && [ "${gpu_driver[$nv]}" = nvidia ]; then
		say ""
		act "Hyprland on NVIDIA wants a few settings (environment variables):"
		note "__GLX_VENDOR_LIBRARY_NAME=nvidia      older (X11) OpenGL apps use the NVIDIA driver"
		note "LIBVA_DRIVER_NAME=nvidia, NVD_BACKEND=direct   video decoding (needs libva-nvidia-driver)"
		if user_sets __GLX_VENDOR_LIBRARY_NAME || user_sets LIBVA_DRIVER_NAME; then
			ok "Your Hyprland config already sets them, so they stay as they are."
		elif ask "Add them to quartz's block in your Hyprland config?" y; then
			hw_nv_env=1
		fi
	fi

	if [ $nv -ge 0 ] && [ $ig -ge 0 ]; then
		igpu_pci=${gpu_pci[$ig]} nv_pci=${gpu_pci[$nv]} igpu_card=${gpu_card[$ig]} nv_card=${gpu_card[$nv]}
		say ""
		act "This is a hybrid laptop: the ${gpu_name[$ig]} is built into the processor and sips power,"
		note "the ${gpu_name[$nv]} is fast but power-hungry. Best: the built-in chip draws the"
		note "desktop and quartz, and the NVIDIA card wakes up only for the apps you ask it to."
		if user_sets AQ_DRM_DEVICES; then
			ok "Your Hyprland config already picks the desktop GPU (AQ_DRM_DEVICES)."
		elif [ "$hypr_mode" = classic ] && [ "${gpu_boot[$ig]}" = 1 ]; then
			ok "Hyprland already draws the desktop on the ${gpu_name[$ig]} (it's the chip your laptop starts the screen with)."
		else
			note "Hyprland normally starts on the chip that showed the boot screen$([ "${gpu_boot[$ig]}" = 1 ] && echo " (here: the built-in one)"); setting"
			note "AQ_DRM_DEVICES makes it certain. Takes effect the next time you log in."
			ask "Make Hyprland draw the desktop on the ${gpu_name[$ig]}?" y && hw_drm=1
		fi
		if [ "${gpu_driver[$nv]}" = nvidia ] && [ -e "$root$NVIDIA_EGL" ] && [ -e "$root$MESA_EGL" ]; then
			note "quartz is drawn by the built-in chip, but NVIDIA's OpenGL libraries still load into it:"
			note "about 125 MB of memory for nothing, and they can keep the NVIDIA card awake."
			if ask "Run quartz on the ${gpu_name[$ig]} only?" y; then
				hw_gpu=1
				note "Apps you open from quartz's launcher start through Hyprland, so they aren't affected."
			fi
		fi
	fi
}

# ── 3. packages ─────────────────────────────────────────────────────────────
planned=()
# packages the rest of the system leans on: --uninstall asks separately before removing these
sys_pkgs=" hyprland networkmanager bluez pipewire pipewire-pulse wireplumber upower glib2 systemd util-linux sof-firmware alsa-ucm-conf zsh git "
rec_pkgs() { local p; for p in "$@"; do [ -n "$p" ] || continue; if [[ $sys_pkgs == *" $p "* ]]; then rec syspkg "$p"; else rec pkg "$p"; fi; done; }
offer_pkgs() { # "what they are" default pkg… → install from the repos / AUR
	local label=$1 def=$2 p
	shift 2
	local -a repo=() aur=() nc=() was=()
	[ $yes -eq 1 ] && nc=(--noconfirm)
	for p in "$@"; do
		if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sp --print-format %n "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
	done
	if [ ${#repo[@]} -gt 0 ]; then
		act "$label, from the Arch repos: ${repo[*]}"
		note "$(shq sudo pacman -S --needed "${nc[@]}" "${repo[@]}")"
		if ask "Install them now?" "$def"; then
			mapfile -t was < <(pacman -T "${repo[@]}" 2>/dev/null)
			if sys_run sudo pacman -S --needed "${nc[@]}" "${repo[@]}"; then planned+=("${repo[@]}"); rec_pkgs "${was[@]}"
			else bad "pacman stopped. Often an update fixes it: sudo pacman -Syu, then run this installer again."; fi
		fi
	fi
	if [ ${#aur[@]} -gt 0 ]; then
		act "$label, from the AUR (community packages): ${aur[*]}"
		if [ -n "$aur_helper" ]; then
			note "$(shq "$aur_helper" -S --needed "${nc[@]}" "${aur[@]}")"
			if ask "Install them now with $aur_helper?" "$def"; then
				mapfile -t was < <(pacman -T "${aur[@]}" 2>/dev/null)
				if sys_run "$aur_helper" -S --needed "${nc[@]}" "${aur[@]}"; then planned+=("${aur[@]}"); rec_pkgs "${was[@]}"
				else bad "$aur_helper stopped; see its messages above."; fi
			fi
		else
			bad "No AUR helper (yay or paru) found. Install one (https://github.com/Jguer/yay),"
			note "or build these by hand from https://aur.archlinux.org, then run this installer again."
		fi
	fi
}
packages() {
	step "Installing what's missing"
	if [ ${#missing_pkgs[@]} -eq 0 ] && [ ${#hw_pkgs[@]} -eq 0 ]; then
		ok "Nothing to install."
	elif [ $is_arch = 1 ]; then
		if in_list pipewire-pulse "${missing_pkgs[@]}" && pacman -Q pulseaudio >/dev/null 2>&1; then
			act "PulseAudio is installed. quartz's sound runs on PipeWire, which takes its place (your apps keep working)."
			if ask "Replace PulseAudio with PipeWire?" y; then
				local -a pa=(pulseaudio)
				pacman -Q pulseaudio-bluetooth >/dev/null 2>&1 && pa+=(pulseaudio-bluetooth)
				sys_run sudo pacman -Rdd --noconfirm "${pa[@]}" || bad "Couldn't remove PulseAudio, so pipewire-pulse can't go in next to it."
			fi
		fi
		[ ${#missing_pkgs[@]} -gt 0 ] && offer_pkgs "quartz needs" y "${missing_pkgs[@]}"
		[ ${#hw_pkgs[@]} -gt 0 ] && offer_pkgs "For your sound chip" y "${hw_pkgs[@]}"
	else
		act "Install these with your distro's package manager (these are Arch's names; yours may differ):"
		[ ${#missing_pkgs[@]} -gt 0 ] && note "quartz needs:      ${missing_pkgs[*]}"
		[ ${#hw_pkgs[@]} -gt 0 ] && note "for your hardware: ${hw_pkgs[*]}"
		note "quartz still runs without them; the parts that need them won't work."
	fi
	if [ $dry -eq 0 ] && [ ${#planned[@]} -gt 0 ]; then
		hash -r
		say "  Checking again:"
		check_deps quiet
		[ "$missing_count" = 0 ] && ok "Everything quartz needs is installed."
	fi
	services
}
services() {
	have systemctl || return 0
	local u
	if have pipewire-pulse; then
		for u in pipewire.socket pipewire-pulse.socket wireplumber.service; do
			systemctl --user is-active --quiet "$u" && continue
			act "Sound: $u isn't running, so there's no sound and quartz's volume can't work."
			ask "Start it now and at every login? (systemctl --user enable --now $u)" y && sys_run systemctl --user enable --now "$u"
		done
	fi
	if have_bluez; then
		if ! systemctl is-active --quiet bluetooth; then
			act "Bluetooth's service isn't running, so quartz can't see your devices."
			ask "Start it now and at every boot? (sudo systemctl enable --now bluetooth)" y && sys_run sudo systemctl enable --now bluetooth
		fi
		if have rfkill && rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes'; then
			act "Bluetooth is switched off (rfkill)."
			ask "Switch it on?" y && { sys_run rfkill unblock bluetooth || sys_run sudo rfkill unblock bluetooth; }
		fi
		ls "$root"/sys/class/bluetooth/hci* >/dev/null 2>&1 || note "No Bluetooth adapter showed up (/sys/class/bluetooth); quartz's Bluetooth page stays empty without one."
	fi
	if { have powerprofilesctl || in_list power-profiles-daemon "${planned[@]}"; } && ! systemctl is-active --quiet power-profiles-daemon; then
		if systemctl is-active --quiet tlp || systemctl is-active --quiet auto-cpufreq || systemctl is-active --quiet tuned; then
			warn "power-profiles-daemon is installed, but another power tool runs (tlp, auto-cpufreq or tuned)."
			note "The two would fight, so I'm leaving it off; quartz's Power mode needs power-profiles-daemon."
		else
			act "power-profiles-daemon's service isn't running, so quartz's Power mode can't switch."
			note "$(shq sudo systemctl enable --now power-profiles-daemon)"
			ask "Start it now and at every boot?" y && sys_run sudo systemctl enable --now power-profiles-daemon
		fi
	fi
	if have nmcli && ! systemctl is-active --quiet NetworkManager; then
		local other=""
		for u in systemd-networkd iwd dhcpcd connman netctl; do systemctl is-active --quiet "$u" && other+=" $u"; done
		if [ -z "$other" ]; then
			act "NetworkManager isn't running, so quartz's Wi-Fi page can't work."
			ask "Start it now and at every boot? (sudo systemctl enable --now NetworkManager)" y && sys_run sudo systemctl enable --now NetworkManager
		else
			warn "NetworkManager isn't running; your network comes from${other}."
			note "Two network managers fight, so I'm leaving it. quartz's Wi-Fi page needs NetworkManager:"
			note "switch with  sudo systemctl disable --now${other} && sudo systemctl enable --now NetworkManager"
		fi
	fi
}

# ── 4. fonts ────────────────────────────────────────────────────────────────
get_font() { # family file url licence
	local fam=$1 file=$2 url=$3 lic=$4 dir=$data_home/fonts tmp magic
	if [ -s "$dir/$file" ]; then
		bad "$(pretty "$dir/$file") is there, but fontconfig doesn't list $fam. Run fc-cache -f, or log out and back in."
		return
	fi
	act "$fam isn't installed. It's free ($lic); I can download it from Google's GitHub into $(pretty "$dir")."
	if ! ask "Download $fam?" y; then note "You can get it later from $url"; return; fi
	if [ $dry -eq 0 ] && [ "${QUARTZ_SKIP_DOWNLOADS:-0}" = 1 ]; then act "skipped (QUARTZ_SKIP_DOWNLOADS): download $url"; return; fi
	if [ $dry -eq 1 ]; then
		act "would download $url"
		act "would save it as $(pretty "$dir/$file") and run: fc-cache -f $(pretty "$dir")"
		return
	fi
	tmp=$(mktemp)
	act "downloading $url"
	if have curl; then curl -fsSL --retry 2 -o "$tmp" "$url"
	elif have wget; then wget -qO "$tmp" "$url"
	else bad "Neither curl nor wget is installed, so I can't download it. Get it from $url"; rm -f "$tmp"; return
	fi || { bad "The download failed. Get it by hand from $url"; rm -f "$tmp"; return; }
	magic=$(head -c4 "$tmp" | od -An -tx1 | tr -d ' \n')
	if [ "$(wc -c <"$tmp")" -lt 20000 ] || ! in_list "$magic" 00010000 74727565 4f54544f; then
		bad "That download isn't a font file. Get it by hand from $url"
		rm -f "$tmp"
		return
	fi
	mkdir -p "$dir" && mv "$tmp" "$dir/$file" && chmod 644 "$dir/$file" && rec file "$dir/$file"
	run_q fc-cache -f "$dir"
	if font_ok "$fam"; then ok "$fam installed."; else bad "Saved $(pretty "$dir/$file"), but fontconfig doesn't list $fam yet; log out and back in."; fi
}
# quartz's cursor. Left alone when your Hyprland config already picks one.
cursor_ok() { local d; for d in "$data_home/icons" "$HOME/.icons" /usr/share/icons; do [ -f "$d/$cursor_theme/cursor.theme" ] && return 0; done; return 1; }
cursor() {
	use_cursor=0
	if user_sets XCURSOR_THEME || user_sets HYPRCURSOR_THEME; then
		ok "Cursor: your Hyprland config already picks one, so quartz leaves it alone."
		note "For quartz's ($cursor_theme), take out your XCURSOR_THEME / HYPRCURSOR_THEME lines and run this again."
		return
	fi
	if cursor_ok; then
		ok "Cursor: $cursor_theme"
		use_cursor=1
		return
	fi
	act "quartz comes with a cursor, $cursor_theme (white, rounded; GPL-3.0). It goes in $(pretty "$data_home/icons")."
	ask "Install it and use it?" y || { note "Your cursor stays as it is."; return; }
	run mkdir -p "$data_home/icons" && run tar -xzf "$cursor_tar" -C "$data_home/icons" && use_cursor=1 && rec file "$data_home/icons/$cursor_theme"
	[ $dry -eq 0 ] && [ $use_cursor = 1 ] && ok "Installed $(pretty "$data_home/icons/$cursor_theme")"
}
fonts() {
	step "Fonts and cursor"
	local fam
	for fam in "Material Symbols Rounded" "Outfit"; do
		if font_ok "$fam"; then ok "$fam"; continue; fi
		if [ "$fam" = "Material Symbols Rounded" ] && [ $dry -eq 1 ] && in_list ttf-material-symbols-variable "${planned[@]}"; then
			ok "$fam comes with ttf-material-symbols-variable (above)"
			continue
		fi
		if [ "$fam" = Outfit ]; then
			get_font Outfit 'Outfit[wght].ttf' \
				'https://raw.githubusercontent.com/google/fonts/main/ofl/outfit/Outfit%5Bwght%5D.ttf' "SIL Open Font License"
		else
			get_font "$fam" 'MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf' \
				'https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf' "Apache License 2.0"
		fi
	done
	cursor
}

# ── 5. link ─────────────────────────────────────────────────────────────────
link() {
	step "Linking quartz into Quickshell"
	note "Quickshell runs the shells in $(pretty "$cfg_home/quickshell"). A link there makes \`qs -c quartz\`"
	note "run the files in $(pretty "$here/shell"), so a \`git pull\` in $(pretty "$here") updates quartz."
	if [ -L "$qs_link" ] && [ "$(readlink -f "$qs_link")" = "$(readlink -f "$here/shell")" ]; then
		ok "$(pretty "$qs_link") already points here."
		return
	fi
	if [ -e "$qs_link" ] || [ -L "$qs_link" ]; then
		act "Something is already at $(pretty "$qs_link"); it gets moved aside, not deleted."
		run mv -- "$qs_link" "$qs_link.backup-$stamp" || { bad "Couldn't move it; leaving everything as it was."; return; }
		rec backup "$qs_link" "$qs_link.backup-$stamp"
	fi
	run mkdir -p "$cfg_home/quickshell" && run ln -s "$here/shell" "$qs_link" && rec link "$qs_link" && [ $dry -eq 0 ] && ok "Linked $(pretty "$qs_link") → $(pretty "$here/shell")"
}

# ── 6. terminal, shell, scripts ─────────────────────────────────────────────
terminal() {
	step "Terminal, shell and scripts"
	note "quartz's terminal: Ghostty with zsh (plugins, history search, fzf, zoxide) and a"
	note "two-line starship prompt."
	place_config "$here/config/ghostty/config" "$cfg_home/ghostty/config" "a Ghostty config"
	place_config "$here/config/zsh/.zshrc" "${ZDOTDIR:-$HOME}/.zshrc" "a .zshrc"
	place_config "$here/config/starship.toml" "$cfg_home/starship.toml" "a starship config"
	local zsh_bin cur f dest
	zsh_bin=$(command -v zsh)
	cur=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
	if [ -n "$zsh_bin" ] && [ -n "$cur" ] && [ "$(basename "$cur")" != zsh ]; then
		act "Your login shell is $cur."
		if ask "Make zsh your shell? (chsh asks for your password)" y; then
			if tty_ok && [ $yes -eq 0 ]; then sys_run chsh -s "$zsh_bin" </dev/tty && rec shell "$cur"
			else note "No terminal for the password; run it yourself: chsh -s $zsh_bin"; fi
		fi
	else
		[ -n "$zsh_bin" ] && ok "Your login shell is zsh."
	fi
	# scripts: linked, so a git pull updates them
	for f in "$here"/scripts/*; do
		[ -f "$f" ] || continue
		dest=$HOME/.local/bin/$(basename "$f")
		if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$f")" ]; then ok "Script: $(basename "$f") ($(pretty "$dest"))"; continue; fi
		if [ -e "$dest" ] || [ -L "$dest" ]; then
			act "You already have $(pretty "$dest")."
			ask "Replace it with quartz's? (yours is moved aside)" n || continue
			aside "$dest"
		fi
		run mkdir -p "$HOME/.local/bin" && run ln -s "$f" "$dest" && rec link "$dest" && [ $dry -eq 0 ] && ok "Script: $(pretty "$dest") → $(pretty "$f")"
	done
}

# ── 6. Hyprland ─────────────────────────────────────────────────────────────
gpu_hints() { # what to add yourself when this installer can't write the block
	[ "${hw_gpu:-0}${hw_drm:-0}${hw_nv_env:-0}${use_cursor:-0}" = 0000 ] && return
	note "For the settings you picked, add these to your own quartz.setup({ … }):"
	[ "${hw_gpu:-0}" = 1 ] && note "  gpu = \"integrated\","
	[ "${hw_drm:-0}" = 1 ] && note "  drm_devices = { \"$igpu_pci\", \"$nv_pci\" },"
	[ "${use_cursor:-0}" = 1 ] && note "  cursor = \"$cursor_theme\","
	[ "${hw_nv_env:-0}" = 1 ] && note "and: hl.env(\"__GLX_VENDOR_LIBRARY_NAME\", \"nvidia\"), plus LIBVA_DRIVER_NAME / NVD_BACKEND = nvidia / direct"
}
hyprland() {
	step "Adding quartz to Hyprland"
	local blk rc l f
	if [ "$hypr_mode" = none ]; then
		act "You don't have a Hyprland config yet, so quartz sets up its clean one: look, layout,"
		note "input and quartz's own keys, nothing else bound."
		run mkdir -p "$hypr_dir" && run cp "$hypr_clean" "$hypr_lua" && rec file "$hypr_lua"
		hypr_mode=lua hypr_file=$hypr_lua fresh=1
	elif is_clean "$hypr_file"; then
		fresh=1
		if [ "$(outside_block "$hypr_file")" = "$(outside_block "$hypr_clean")" ]; then
			ok "Your Hyprland config is quartz's clean one."
		else
			act "Your Hyprland config is quartz's clean one, changed (by you, or quartz has a newer one)."
			if ask "Replace it with quartz's current one? (yours is moved aside)" n; then
				aside "$hypr_file"
				run cp "$hypr_clean" "$hypr_lua" && rec file "$hypr_lua"
			fi
		fi
	else
		act "You have your own Hyprland config: $(pretty "$hypr_file")"
		note "quartz can replace it with its clean one (yours is moved aside and comes back with"
		note "--uninstall), or keep yours and add quartz's block at the end (your keys stay yours)."
		if ask "Replace it with quartz's clean config?" n; then
			for f in "$hypr_lua" "$hypr_conf"; do { [ -e "$f" ] || [ -L "$f" ]; } && aside "$f"; done
			run cp "$hypr_clean" "$hypr_lua" && rec file "$hypr_lua"
			hypr_mode=lua hypr_file=$hypr_lua fresh=1
		fi
	fi
	scan_hypr
	ok "Your Hyprland config: $(pretty "$hypr_file") ($([ "$hypr_mode" = lua ] && echo "Lua" || echo "classic") format)"
	if [ -n "$elsewhere" ]; then
		ok "It already loads quartz:"
		while IFS= read -r l; do note "$(pretty "${l%%:*}"):$(cut -d: -f2 <<<"$l"):$(cut -d: -f3- <<<"$l" | sed 's/^[[:space:]]*/ /' | cut -c1-90)"; done <<<"$elsewhere"
		note "Leaving it alone: loading quartz twice would bind every key twice."
		gpu_hints
		return
	fi
	if [ "$(block_state "$hypr_file")" = broken ]; then
		bad "$(pretty "$hypr_file") has a \">>> quartz >>>\" line without its matching \"<<< quartz <<<\" (or two blocks)."
		note "Fix or delete those lines by hand, then run this installer again."
		return
	fi
	find_conflicts
	choose_keymap
	[ "$user_clip" = 1 ] && ok "Your config already starts cliphist, so quartz's block doesn't start it again."
	blk=$(mktemp)
	make_block >"$blk"
	if [ "$(block_state "$hypr_file")" = ok ] && [ "$(block_text "$hypr_file")" = "$(cat "$blk")" ]; then
		ok "$(pretty "$hypr_file") already has quartz's block, up to date."
		rm -f "$blk"
		return
	fi
	note "quartz's keys, rules and autostart go in one block, between \">>> quartz >>>\" lines at"
	note "the end of your config. Running this installer again updates it; --uninstall removes it."
	ask_ynp "$([ "$(block_state "$hypr_file")" = ok ] && echo "Update quartz's block in" || echo "Add quartz to") $(pretty "$hypr_file")? (backed up first)"
	rc=$?
	case $rc in
		0) put_block "$hypr_file" "$blk" ;;
		2) say ""; say "Add this to the end of $(pretty "$hypr_file"):"; say ""; cat "$blk"; say "" ;;
		*) note "Left your config alone. Run this again (or see README.md) to add it later." ;;
	esac
	rm -f "$blk"
}

# ── 7. wallpapers ───────────────────────────────────────────────────────────
wallpapers() {
	step "Wallpapers"
	local cfg=$state_dir/config.json wdir theme=true json f
	note "quartz takes its colours from your wallpaper. Its picker (Super + C) shows the pictures in"
	note "one folder; that folder's subfolders become filters."
	if [ -e "$cfg" ]; then
		wdir=$(sed -nE 's/.*"wallpaperDir"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$cfg" | head -1)
		[ -z "$wdir" ] && wdir=$HOME/wallpapers
		ok "quartz already has its settings ($(pretty "$cfg")); leaving them as they are."
		ok "Wallpaper folder: $(pretty "$wdir")"
		[ -d "$wdir" ] || { ask "That folder doesn't exist. Create it?" y && run mkdir -p "$wdir"; }
	else
		ask_path "Where do you keep (or want to keep) your wallpapers?" "$HOME/wallpapers"
		wdir=$answer
		[ -d "$wdir" ] || { run mkdir -p "$wdir" && rec dir "$wdir"; }
		if [ -f "$cfg_home/matugen/config.toml" ]; then
			act "You already have a matugen config ($(pretty "$cfg_home/matugen/config.toml"))."
			note "quartz can run it on every new wallpaper, so the apps it themes follow quartz's colours."
			note "That rewrites whatever those templates write (terminal themes and the like)."
			ask "Let quartz run your matugen config on wallpaper changes?" n || theme=false
		fi
		json=$(printf '{\n  "wallpaperDir": "%s"' "$(sed 's/\\/\\\\/g; s/"/\\"/g' <<<"$wdir")")
		[ $theme = false ] && json+=$',\n  "themeApps": false'
		json+=$'\n}'
		if [ $dry -eq 1 ]; then
			act "would create $(pretty "$cfg"):"
			sed 's/^/      /' <<<"$json"
		else
			mkdir -p "$state_dir" && printf '%s\n' "$json" >"$cfg" && rec file "$cfg" && ok "Saved quartz's settings: $(pretty "$cfg")"
		fi
	fi
	if [ -d "$wdir" ] && find -L "$wdir" -maxdepth 4 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \) 2>/dev/null | grep -q .; then
		ok "It has pictures in it."
	else
		copy_wallpapers "$wdir"
	fi
	first_wallpaper "$cfg" "$wdir"
}
copy_wallpapers() {
	local wdir=$1 f
	local -a ours=()
	for f in "$here"/wallpapers/*; do [ -f "$f" ] && ours+=("$f"); done
	if [ ${#ours[@]} -gt 0 ]; then
		act "The folder is empty. quartz comes with ${#ours[@]} wallpapers."
		if ask "Copy them in so quartz has something to start with?" y; then
			for f in "${ours[@]}"; do run cp -n -- "$f" "$wdir/" && rec file "$wdir/$(basename "$f")"; done
		fi
	else
		act "The folder is empty: put some pictures (jpg or png) in $(pretty "$wdir"), then pick one with Super + C."
	fi
}
# first_wallpaper settings folder → no wallpaper chosen yet: start on quartz's calm default
# (else the folder's first picture), so the desktop doesn't come up on Hyprland's own
first_wallpaper() {
	local cfg=$1 wdir=$2 w
	[ -f "$cfg" ] || return 0
	grep -qE '"wallpaper"[[:space:]]*:[[:space:]]*"[^"]' "$cfg" && return 0
	w=$wdir/lake_mountain.jpg
	[ -f "$w" ] || w=$(find -L "$wdir" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -n1)
	[ -n "$w" ] || return 0
	case $w in *[\"\\\|\&]*) note "Pick your first wallpaper with Super + C."; return 0 ;; esac
	if grep -qE '"wallpaper"[[:space:]]*:' "$cfg"; then
		run sed -i -E "s|\"wallpaper\"[[:space:]]*:[[:space:]]*\"\"|\"wallpaper\": \"$w\"|" "$cfg"
	else
		run sed -i "0,/{/s|{|{\n  \"wallpaper\": \"$w\",|" "$cfg"
	fi
	[ $dry -eq 0 ] && ok "Starting wallpaper: $(pretty "$w") (change it with Super + C)"
	quartz_running && note "quartz is running: restart it (Super + Shift + R) to show it."
	return 0
}

# ── 8. start ────────────────────────────────────────────────────────────────
others_running() { # other bars / notification daemons / wallpaper tools that clash
	local p
	local -a list=()
	for p in waybar eww ags hyprpanel nwg-panel mako dunst swaync hyprpaper swww-daemon; do pgrep -x "$p" >/dev/null 2>&1 && list+=("$p"); done
	pgrep -af '^([^ ]*/)?(qs|quickshell)( |$)' 2>/dev/null | grep -vE -- '-c quartz( |$)| ipc ' | grep -q . && list+=("another Quickshell shell")
	[ ${#list[@]} -eq 0 ] && return
	warn "Also running: ${list[*]}."
	note "quartz brings its own bar, notifications and wallpaper. Stop those (and take them out of your"
	note "Hyprland autostart), or you'll get two of each."
}
start() {
	step "Starting quartz"
	if ! hypr_running; then
		act "Hyprland isn't running here. Log in to Hyprland and quartz starts with it."
		return
	fi
	if ! hypr_ours; then
		act "Hyprland is running, but from another config folder than $(pretty "$hypr_dir"),"
		note "so this installer doesn't reload it or start quartz in it."
		return
	fi
	if [ "${hypr_changed:-0}" = 1 ]; then
		if ask "Reload Hyprland now so it picks up quartz's keys and rules?" y; then
			run_q hyprctl reload
			if [ $dry -eq 0 ]; then
				local errs l
				errs=$(hyprctl configerrors 2>/dev/null | grep -v '^[[:space:]]*$')
				if [ -n "$errs" ]; then
					bad "Hyprland reports problems in your config:"
					while IFS= read -r l; do note "$l"; done <<<"$errs"
					note "If they're about quartz, run $(pretty "$here")/install.sh --uninstall to take its block out again."
				else
					ok "Hyprland reloaded, no config errors."
				fi
			fi
			[ "${hw_drm:-0}" = 1 ] && note "The desktop GPU setting (AQ_DRM_DEVICES) takes effect the next time you log in."
		fi
	fi
	others_running
	if quartz_running; then
		ok "quartz is already running. (Restart it with Super + Shift + R.)"
	elif ask "Start quartz now?" y; then
		if [ $dry -eq 1 ]; then
			act "would run: $(qs_start)"
		else
			act "$(qs_start)"
			bash -c "$(qs_start)" >/dev/null 2>&1 </dev/null
			local i
			for i in 1 2 3 4 5 6; do quartz_running && break; sleep 0.5; done
			if quartz_running; then ok "quartz is running."; else bad "quartz didn't start. See what went wrong with: qs log -c quartz"; fi
		fi
	fi
	if [ "$user_clip" = 0 ] && ! pgrep -f 'wl-paste .*--watch cliphist store' >/dev/null 2>&1 && have cliphist; then
		if [ $dry -eq 1 ]; then
			act "would start the clipboard-history watchers: wl-paste --type text|image --watch cliphist store"
		else
			setsid -f wl-paste --type text --watch cliphist store >/dev/null 2>&1 </dev/null
			setsid -f wl-paste --type image --watch cliphist store >/dev/null 2>&1 </dev/null
			ok "Clipboard history is recording (from the next login, Hyprland starts it)."
		fi
	fi
}

what_next() {
	local k label
	say ""
	if [ $dry -eq 1 ]; then
		say "${B}Dry run: nothing was changed.${N} Run it again without --dry-run to do all this."
		return
	fi
	say "${B}Next:${N}"
	while IFS='|' read -r k label; do
		if in_list "${k^^}" "${skip_keys[@]^^}"; then
			say "  $(printf '%-14s %s' "$(pretty_key "$k")" "$label") ${D}(your config uses this key; quartz left it alone)${N}"
		else
			say "  $(printf '%-14s %s' "$(pretty_key "$k")" "$label")"
		fi
	done <<'EOF'
SUPER + Space|open apps (launcher)
SUPER + A|control centre: Wi-Fi, Bluetooth, sound, notifications
SUPER + slash|every quartz shortcut
SUPER + comma|settings
SUPER + C|pick a wallpaper
EOF
	say "  Undo all of it: $(pretty "$here")/install.sh --uninstall   Start over: --reinstall"
	hash -r
	check_deps silent
	problems=$((problems + missing_count))
	if [ $problems -gt 0 ]; then
		say ""
		say "  ${R}✗${N} $problems thing(s) above still need you (marked ✗)."
	fi
}

# ── uninstall ───────────────────────────────────────────────────────────────
uninstall() {
	step_total=5
	local f l found=0 kind a b i
	local -a pkgs=() syspkgs=() lines=()
	step "Removing the quartz link"
	if [ -L "$qs_link" ] && [ "$(readlink -f "$qs_link")" = "$(readlink -f "$here/shell")" ]; then
		run rm -- "$qs_link" && [ $dry -eq 0 ] && ok "Removed $(pretty "$qs_link")."
	elif [ -e "$qs_link" ] || [ -L "$qs_link" ]; then
		warn "$(pretty "$qs_link") isn't a link to $(pretty "$here/shell"), so it isn't this installer's. Leaving it."
	else
		ok "There's no $(pretty "$qs_link") to remove."
	fi

	step "Removing quartz's block from your Hyprland config"
	for f in "$hypr_lua" "$hypr_conf"; do
		case $(block_state "$f") in
			ok) found=1; remove_block "$f" ;;
			broken) found=1; bad "$(pretty "$f") has a broken quartz block (a marker line without its pair). Remove it by hand." ;;
		esac
	done
	[ $found = 0 ] && ok "No quartz block in $(pretty "$hypr_dir")."
	elsewhere=""
	[ "$hypr_mode" != none ] && scan_hypr
	if [ -n "$elsewhere" ]; then
		note "Your config also loads quartz somewhere this installer didn't write (left as it is):"
		while IFS= read -r l; do note "  $(pretty "${l%%:*}"):$(cut -d: -f2 <<<"$l")"; done <<<"$elsewhere"
	fi

	step "Removing what the installer added"
	if hypr_live && quartz_running; then
		ask "quartz is running. Stop it now?" y && run_q qs kill -c quartz
	fi
	if [ -f "$manifest" ]; then
		mapfile -t lines <"$manifest"
		# newest first, so a file is removed before the one it replaced comes back
		for ((i = ${#lines[@]} - 1; i >= 0; i--)); do
			IFS=$'\t' read -r kind a b <<<"${lines[$i]}"
			case $kind in
				file) if [ -e "$a" ] || [ -L "$a" ]; then run rm -rf -- "$a" && [ $dry -eq 0 ] && ok "Removed $(pretty "$a")"; fi ;;
				link) if [ -L "$a" ]; then run rm -- "$a" && [ $dry -eq 0 ] && ok "Removed $(pretty "$a")"; fi ;;
				dir) if [ -d "$a" ] && [ -z "$(ls -A "$a" 2>/dev/null)" ]; then run rmdir -- "$a"; fi ;;
				backup)
					if [ -e "$b" ] || [ -L "$b" ]; then
						if [ -e "$a" ] || [ -L "$a" ]; then run rm -rf -- "$a"; fi
						run mv -- "$b" "$a" && [ $dry -eq 0 ] && ok "Put yours back: $(pretty "$a")"
					fi ;;
				shell) if ask "Switch your login shell back to $a?" y; then
						if tty_ok && [ $yes -eq 0 ]; then sys_run chsh -s "$a" </dev/tty; else note "Run it yourself: chsh -s $a"; fi
					fi ;;
				pkg) if pacman -Q "$a" >/dev/null 2>&1 && ! in_list "$a" "${pkgs[@]}"; then pkgs+=("$a"); fi ;;
				syspkg) if pacman -Q "$a" >/dev/null 2>&1 && ! in_list "$a" "${syspkgs[@]}"; then syspkgs+=("$a"); fi ;;
			esac
		done
	else
		note "No record of an install here ($(pretty "$manifest")): removing only quartz's settings and caches."
	fi
	# quartz's .zshrc fetched zinit and its plugins, and compinit left its cache
	if recorded file "${ZDOTDIR:-$HOME}/.zshrc"; then
		for f in "$data_home/zinit" "${ZDOTDIR:-$HOME}"/.zcompdump*; do
			if [ -e "$f" ]; then run rm -rf -- "$f" && [ $dry -eq 0 ] && ok "Removed $(pretty "$f")"; fi
		done
	fi
	if recorded file "$cfg_home/starship.toml" && [ -d "$HOME/.cache/starship" ]; then run rm -rf -- "$HOME/.cache/starship"; fi
	for f in "$state_dir" "$cache_dir"; do
		if [ -e "$f" ]; then run rm -rf -- "$f" && [ $dry -eq 0 ] && ok "Removed $(pretty "$f")"; fi
	done
	# folders the installer made that are empty now (rmdir only takes empty ones; it stops at the first that isn't)
	if [ $dry -eq 0 ]; then
		for l in "${lines[@]}"; do
			IFS=$'\t' read -r kind a b <<<"$l"
			case $kind in file | link | dir) tidy "$(dirname "$a")" ;; esac
		done
		for f in "$cfg_home/quickshell" "$HOME/.cache/x" "$state_dir"; do tidy "$(dirname "$f")"; done
	fi

	step "Packages"
	if [ "${keep_pkgs:-0}" = 1 ]; then
		ok "--reinstall: the packages stay."
	elif [ ${#pkgs[@]} -eq 0 ] && [ ${#syspkgs[@]} -eq 0 ]; then
		ok "This installer didn't install any packages that are still here."
	else
		if [ ${#pkgs[@]} -gt 0 ]; then
			act "Installed for quartz: ${pkgs[*]}"
			ask "Remove them?" y && remove_pkgs "${pkgs[@]}"
		fi
		if [ ${#syspkgs[@]} -gt 0 ]; then
			act "Also installed by it, and your system leans on them (network, sound, Bluetooth, shell): ${syspkgs[*]}"
			note "Without them there's no network, sound or Bluetooth until you set up others."
			ask "Remove these too?" n && remove_pkgs "${syspkgs[@]}"
		fi
	fi

	step "Finishing"
	if hypr_live && [ "${hypr_changed:-0}" = 1 ]; then
		ask "Reload Hyprland now so quartz's keys go away?" y && run_q hyprctl reload
	fi
	say ""
	say "Left in place: your wallpapers (only the ones quartz copied in are gone) and the quartz"
	say "folder itself ($(pretty "$here")); delete that by hand if you're done with it."
	[ $dry -eq 1 ] && say "${B}Dry run: nothing was changed.${N}"
	return 0
}
# tidy dir → remove it and its parents while they're empty, never $HOME or anything above it
tidy() {
	local d=$1
	while [[ $d == "$HOME"/?* ]] && [ -d "$d" ] && [ -z "$(ls -A "$d" 2>/dev/null)" ]; do
		rmdir -- "$d" 2>/dev/null || break
		d=$(dirname "$d")
	done
}
# remove_pkgs pkg… → pacman -Rns; one by one when something else needs one of them
remove_pkgs() {
	local p
	sys_run sudo pacman -Rns --noconfirm "$@" && return
	note "pacman wouldn't remove them all at once; trying one at a time."
	for p in "$@"; do sys_run sudo pacman -Rns --noconfirm "$p" >/dev/null 2>&1 || note "Kept $p: something else needs it."; done
}

# ── main ────────────────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
	say "Run this as your normal user, not with sudo: it asks for your password itself when it needs it."
	exit 1
fi
if [ ! -f "$here/shell/shell.qml" ] || [ ! -f "$here/hypr/quartz.lua" ]; then
	say "Can't find quartz's files next to this script ($here). Run the install.sh inside the quartz folder you cloned."
	exit 1
fi

say "${B}quartz installer${N}"
if [ $mode = uninstall ]; then
	say "This undoes what the installer did: its configs, links, fonts, cursor, wallpapers, settings"
	say "and caches go, the configs it replaced come back, and it offers to remove its packages."
elif [ $mode = reinstall ]; then
	say "This removes quartz (keeping the packages), then sets it up again from scratch."
else
	say "This sets up quartz, a desktop shell for Hyprland (bar, panels, launcher, notifications,"
	say "lock screen). It explains each step and asks before it installs or changes anything;"
	say "any file it edits is backed up first."
fi
[ $dry -eq 1 ] && say "${Y}Dry run: showing what would happen. Nothing gets changed.${N}"
[ $yes -eq 1 ] && say "--yes: taking the default answer to every question."

if [ $mode = uninstall ]; then
	uninstall
	exit 0
fi
if [ $mode = reinstall ]; then
	keep_pkgs=1 uninstall
	[ $dry -eq 1 ] && { say ""; say "(Dry run: the install below sees your files as they are now, not as the removal would leave them.)"; }
	detect_hypr
	step_n=0 step_total=9 hypr_changed=0
	say ""
	say "${B}Installing again${N}"
fi

skip_keys=() user_clip=0 elsewhere="" fresh=0 keymap=0
[ "$hypr_mode" != none ] && scan_hypr
step "Checking what quartz needs"
check_deps
[ $is_arch = 0 ] && note "(Not Arch Linux: I'll list what's missing instead of installing it.)"
hardware
packages
fonts
link
terminal
hyprland
wallpapers
start
what_next
