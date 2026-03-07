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

is_base_start_sh_valid() {
    local f="/home/vncuser/start.sh"
    [[ -s "$f" ]] || return 1
    grep -q 'mkdir -p /home/vncuser/.vnc' "$f" || return 1
    grep -q 'Xvfb :0 -screen 0' "$f" || return 1
    grep -q 'if ! kill -0' "$f" || return 1
}

repair_base_start_sh_if_needed() {
    if is_base_start_sh_valid; then
        return 0
    fi

    if [[ -f "/app/base-start.sh" ]]; then
        echo "[warn] invalid /home/vncuser/start.sh detected; restoring from /app/base-start.sh"
        cp /app/base-start.sh /home/vncuser/start.sh
        chmod +x /home/vncuser/start.sh
        if ! is_base_start_sh_valid; then
            echo "[error] restored /home/vncuser/start.sh is still invalid"
            return 1
        fi
    else
        echo "[error] /home/vncuser/start.sh is invalid and /app/base-start.sh is missing"
        return 1
    fi
}

start_panel
apply_firefox_proxy
cleanup_locks
repair_base_start_sh_if_needed

if [[ -f "/home/vncuser/start.sh" ]]; then
    sed -i 's/ -localhost//g' /home/vncuser/start.sh || true
fi

if [[ -x "/home/vncuser/start.sh" ]]; then
    exec /home/vncuser/start.sh
else
    echo "[error] base start.sh not found at /home/vncuser/start.sh"
    tail -f /dev/null
fi
