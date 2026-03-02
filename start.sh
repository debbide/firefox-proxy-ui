#!/usr/bin/env bash
set -e

DATA_DIR="${DATA_DIR:-/app/data}"
FIREFOX_PROXY_HOST="${FIREFOX_PROXY_HOST:-127.0.0.1}"
FIREFOX_PROXY_PORT="${FIREFOX_PROXY_PORT:-20000}"
FIREFOX_PROXY_ENABLE="${FIREFOX_PROXY_ENABLE:-0}"
export PROXY_CONFIG_DIR="${PROXY_CONFIG_DIR:-$DATA_DIR}"

mkdir -p "$DATA_DIR"

start_panel() {
    echo "[panel] starting on :5000"
    python3 /app/app.py &
}

apply_firefox_proxy() {
    if [[ "$FIREFOX_PROXY_ENABLE" != "1" ]]; then
        local profiles_ini="/home/vncuser/.mozilla/firefox/profiles.ini"
        if [[ -f "$profiles_ini" ]]; then
            local default_path
            default_path=$(awk -F= '/^Path=/{print $2; exit}' "$profiles_ini" || true)
            if [[ -n "$default_path" ]]; then
                local profile_dir="/home/vncuser/.mozilla/firefox/${default_path}"
                mkdir -p "$profile_dir"
                cat > "${profile_dir}/user.js" <<EOF
user_pref("network.proxy.type", 0);
EOF
            fi
        fi
        return 0
    fi
    local profiles_ini="/home/vncuser/.mozilla/firefox/profiles.ini"
    if [[ ! -f "$profiles_ini" ]]; then
        return 0
    fi

    local default_path
    default_path=$(awk -F= '/^Path=/{print $2; exit}' "$profiles_ini" || true)
    if [[ -z "$default_path" ]]; then
        return 0
    fi

    local profile_dir="/home/vncuser/.mozilla/firefox/${default_path}"
    mkdir -p "$profile_dir"

    cat > "${profile_dir}/user.js" <<EOF
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "${FIREFOX_PROXY_HOST}");
user_pref("network.proxy.socks_port", ${FIREFOX_PROXY_PORT});
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, ::1");
EOF
}

cleanup_locks() {
    find /home/vncuser/.mozilla -name "lock" -delete || true
    find /home/vncuser/.mozilla -name ".parentlock" -delete || true
}

start_panel
apply_firefox_proxy
cleanup_locks

if [[ -f "/home/vncuser/start.sh" ]]; then
    sed -i 's/ -localhost//g' /home/vncuser/start.sh || true
fi

if [[ -x "/home/vncuser/start.sh" ]]; then
    exec /home/vncuser/start.sh
else
    echo "[error] base start.sh not found at /home/vncuser/start.sh"
    tail -f /dev/null
fi
