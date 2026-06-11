#!/bin/sh
# bin/lib/platform.sh — shared platform utilities for Wifi.pak
# Source with: . "$BIN_DIR/lib/platform.sh"
# BIN_DIR must be set before sourcing (dirname of the calling script)

[ -z "$BIN_DIR" ] && echo "platform.sh: BIN_DIR must be set" && exit 1

PAK_DIR="$(dirname "$BIN_DIR")"

# Logging helpers (available to all scripts that source platform.sh)
log_debug() { echo "[$(date '+%H:%M:%S')] $*"; }
log_step()  { log_debug "STEP $*"; }
log_ok()    { log_debug "  OK $*"; }
log_fail()  { log_debug "  FAIL $*"; }

# Architecture detection
ARCHITECTURE=arm
if uname -m | grep -q '64'; then
    ARCHITECTURE=arm64
fi

export PATH="$PAK_DIR/bin/$ARCHITECTURE:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PAK_DIR/lib/$PLATFORM:$PAK_DIR/lib:$LD_LIBRARY_PATH"

# Normalize platform aliases (tg3040 -> tg5040)
normalize_platform() {
    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi
}

# Get system.json path for current platform
get_system_json_path() {
    case "$PLATFORM" in
        miyoomini) echo "/appconfigs/system.json" ;;
        my282)     echo "/config/system.json" ;;
        my355)     echo "/userdata/system.json" ;;
        *)         echo "/mnt/UDISK/system.json" ;;
    esac
}

# Check if platform supports system.json-based wifi state
has_system_json() {
    case "$PLATFORM" in
        miyoomini|my282|my355|tg5040|zero28) return 0 ;;
        *) return 1 ;;
    esac
}

# Write wifi state to system.json (0 or 1)
set_system_json() {
    value="$1"
    json_path="$(get_system_json_path)"
    log_debug "set_system_json value=$value path=$json_path"

    [ ! -f "$json_path" ] && echo '{"wifi": 0}' >"$json_path"
    [ ! -s "$json_path" ] && echo '{"wifi": 0}' >"$json_path"

    if [ -x /usr/trimui/bin/systemval ]; then
        log_debug "using systemval wifi $value"
        /usr/trimui/bin/systemval wifi "$value"
    else
        log_debug "using jq to set wifi=$value"
        chmod +x "$PAK_DIR/bin/$ARCHITECTURE/jq"
        jq ".wifi = $value" "$json_path" >"/tmp/system.json.tmp"
        mv "/tmp/system.json.tmp" "$json_path"
    fi
}

# Read wifi state from system.json (echoes "1" or "0")
get_system_json() {
    json_path="$(get_system_json_path)"

    [ ! -f "$json_path" ] && echo '{"wifi": 0}' >"$json_path"
    [ ! -s "$json_path" ] && echo '{"wifi": 0}' >"$json_path"

    if [ -x /usr/trimui/bin/systemval ]; then
        log_debug "get_system_json via systemval"
        /usr/trimui/bin/systemval wifi
    else
        log_debug "get_system_json via jq from $json_path"
        chmod +x "$PAK_DIR/bin/$ARCHITECTURE/jq"
        jq '.wifi' "$json_path"
    fi
}

# Check if platform uses a per-platform wpa_supplicant template
has_custom_wpa_template() {
    case "$PLATFORM" in
        miyoomini|my282|my355) return 0 ;;
        *) return 1 ;;
    esac
}

# Get correct wpa_supplicant template path for current platform
get_wpa_template_path() {
    if has_custom_wpa_template; then
        echo "$PAK_DIR/res/wpa_supplicant.conf.$PLATFORM.tmpl"
    else
        echo "$PAK_DIR/res/wpa_supplicant.conf.tmpl"
    fi
}

# Wpa supplicant destination config path for current platform
# Returns: <dest_path> [<extra_path>]
# rg35xxplus also generates netplan.yaml
get_wpa_conf_path() {
    case "$PLATFORM" in
        miyoomini) echo "/etc/wifi/wpa_supplicant.conf /appconfigs/wpa_supplicant.conf" ;;
        my282)     echo "/etc/wifi/wpa_supplicant.conf /config/wpa_supplicant.conf" ;;
        my355)     echo "/userdata/cfg/wpa_supplicant.conf" ;;
        rg35xxplus) echo "/etc/wpa_supplicant/wpa_supplicant.conf" ;;
        tg5040|zero28) echo "/etc/wifi/wpa_supplicant.conf" ;;
        *)         echo "" ;;  # unsupported
    esac
}

# Copy wpa_supplicant.conf to the correct platform destination(s)
# Only has_netplan() platforms get netplan.yaml generation
install_wpa_config() {
    src="$1"
    dests="$(get_wpa_conf_path)"
    log_debug "install_wpa_config src=$src dests='$dests'"
    if [ -z "$dests" ]; then
        log_fail "no wpa config dest path for $PLATFORM"
        return 1
    fi
    for dest in $dests; do
        # Ensure parent directory exists (rootfs may not have /etc/wifi/ pre-created)
        dest_dir="$(dirname "$dest")"
        if [ ! -d "$dest_dir" ]; then
            log_debug "creating directory $dest_dir"
            mkdir -p "$dest_dir"
        fi
        log_debug "cp $src -> $dest"
        cp "$src" "$dest" || {
            log_fail "cp failed: $src -> $dest"
            return 1
        }
        log_ok "copied to $dest"
    done
}

# Does this platform use netplan?
has_netplan() {
    [ "$PLATFORM" = "rg35xxplus" ]
}

# Parse a single wifi credential line from wifi.txt
# Sets: parsed_ssid, parsed_psk (empty if invalid)
# Returns: 0 if valid, 1 if invalid
parse_wifi_line() {
    line="$1"
    line="$(echo "$line" | xargs)"
    [ -z "$line" ] && return 1
    echo "$line" | grep -q "^#" && return 1
    echo "$line" | grep -q ":" || return 1
    parsed_ssid="$(echo "$line" | cut -d: -f1 | xargs)"
    [ -z "$parsed_ssid" ] && return 1
    # shellcheck disable=SC2034
    parsed_psk="$(echo "$line" | cut -d: -f2- | xargs)"
    return 0
}
