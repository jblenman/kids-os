#!/usr/bin/env bash
# End-to-end test of the v1b shell under QEMU (image built with KIDS_OS_PIN=1234): PIN screen → unlock → launcher → launch → sign out.
# usage: [KIDS_OS_SECRETS=…/secrets-test.env] bash test-v1b.sh ~/kids-os-build/kids-os_<version>.raw   (ssh user = the image's admin)
set -uo pipefail
IMG="$1"; NOBOOT="${2:-}"; cd "$(dirname "$0")"; . ./lib/env.sh; OUT="$KIDS_OS_OUT"
S() { ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 "$ADMIN"@localhost "$@" 2>&1 | grep -v "Could not chdir"; }
shot() { cp -f "$(./qemu-mon.py shot)" "$OUT/$1.png"; echo "shot: $1"; }
if [ "$NOBOOT" != "--no-boot" ]; then
  pgrep -x qemu-system-x86_64 >/dev/null && pkill -x qemu-system-x86_64; sleep 1
  ./test-qemu.sh efi "$IMG" >/dev/null
  n=0; until ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 "$ADMIN"@localhost true >/dev/null 2>&1; do n=$((n+1)); [ $n -ge 180 ] && { echo "no ssh"; ./qemu-mon.py quit >/dev/null 2>&1; exit 1; }; sleep 5; done; echo "ssh after ~$((n*5)) s"; sleep 60
fi
echo "== STEP 1 (boot with a PIN)"; S 'echo "sessiond=$(systemctl is-active kids-sessiond) greeter=$(systemctl is-active greeter-session) kid=$(systemctl is-active kid-session) failed=$(systemctl --failed --no-legend | tr "\n" ";")"; echo "pin: $(sudo test -f /etc/kids-os/pin.hash && echo set || echo none); api: $(curl -s -m 3 localhost:7707/api/config | cut -c1-90)"; echo "--- greeter journal:"; sudo journalctl -b -u greeter-session -o cat --no-pager | grep -v "^$" | tail -8 | cut -c1-160; echo "--- sessiond journal:"; sudo journalctl -b -u kids-sessiond -o cat --no-pager | tail -4 | cut -c1-160; echo "--- greeter procs: cage $(pgrep -c -x cage) chrome $(pgrep -c -x chrome); sessions: $(loginctl list-sessions --no-legend | grep -c seat0)"'
shot v1b-1-pin
echo "== STEP 2 (type 1234 + Enter)"; for k in 1 2 3 4 ret; do ./qemu-mon.py sendkey $k >/dev/null; sleep 1; done; sleep 75
S 'echo "greeter=$(systemctl is-active greeter-session) kid=$(systemctl is-active kid-session) unlocked=$(test -f /run/kids-os/unlocked && echo yes || echo no); procs: labwc $(pgrep -c -x labwc) waybar $(pgrep -c -x waybar) chrome $(pgrep -c -x chrome)"; sudo journalctl -b -u kids-sessiond -o cat --no-pager | tail -3'
shot v1b-2-session
echo "== STEP 3 (launcher)"; S 'sudo -u kid XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 nohup /usr/lib/kids-os/launcher-open >/dev/null 2>&1 & sleep 50; echo "launcher chrome procs: $(pgrep -c -f user-data-dir=/run/kids-os/launcher)"'
shot v1b-3-launcher
echo "== STEP 4 (launch a URL)"; S 'curl -s -m 10 -w " [HTTP %{http_code}]" -X POST -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}" localhost:7707/api/launch; echo; sleep 30; echo "launcher left: $(pgrep -c -f user-data-dir=/run/kids-os/launcher); chrome $(pgrep -c -x chrome)"; sudo journalctl -b -u kids-sessiond -o cat --no-pager | tail -6 | cut -c1-160'
shot v1b-4-launched
echo "== STEP 5 (sign out)"; S 'curl -s -m 5 -X POST localhost:7707/api/signout; echo; sleep 45; echo "greeter=$(systemctl is-active greeter-session) kid=$(systemctl is-active kid-session) unlocked=$(test -f /run/kids-os/unlocked && echo yes || echo no) failed=$(systemctl --failed --no-legend | wc -l)"; for u in $(systemctl --failed --no-legend --plain | awk "{print \$1}"); do echo "--- failed unit $u: $(systemctl show $u -p Result,ExecMainStatus | tr "\n" " ")"; sudo journalctl -b -u $u -o short-iso --no-pager -q | tail -n 8 | cut -c1-200; done'
shot v1b-5-signedout
./qemu-mon.py quit >/dev/null 2>&1; echo "test done"
