# Ideas Backlog

## Deferred / Promising but not pursued

### Extract wpa_supplicant startup into platform.sh
`bin/service-on` still has per-platform startup code:
- miyoomini: uses `/customer/app/wpa_supplicant`, `axp_test wifion`, custom udhcpc
- tg5040/zero28: `wpa_supplicant -B -D nl80211 -iwlan0 -c /etc/wifi/... -O /etc/wifi/sockets`
- my282: `/etc/init.d/wpa_supplicant start`
- my355: `wpa_supplicant -B -D nl80211 -iwlan0 -c /userdata/cfg/...`
- rg35xxplus: `systemctl start wpa_supplicant; netplan apply`

Could extract an `install_wpa_supplicant()` function to platform.sh that handles per-platform startup. This would make `service-on` a simple: `install_wpa_supplicant && udhcpc -i wlan0 -n &`

### Platform family abstraction
Current platform IDs: miyoomini (Sigmastar), my282 (Sigmastar), my355 (Sigmastar), tg5040 (A133), zero28 (A133), rg35xxplus (Actions).
Could codify platform families to avoid repeating `|` chains. E.g.:
```
is_platform_family() {
  case "$PLATFORM" in
    miyoomini|my282|my355) [ "$1" = "sigmastar" ] && return 0 ;;
    tg5040|zero28)        [ "$1" = "a133" ] && return 0 ;;
    rg35xxplus)           [ "$1" = "anbernic" ] && return 0 ;;
  esac
  return 1
}
```

### Functional validation on real Zero 28 hardware
The only meaningful next step. Both proxy metrics are saturated at 0.
