# Shared by the scripts: where the per-family configuration lives, who the admin is, where images go.
# Each value: the environment first, then a KEY=VALUE line in the secrets file, then the default.
KIDS_OS_CONFIG="${KIDS_OS_CONFIG:-$HOME/.config/kids-os}"
KIDS_OS_SECRETS="${KIDS_OS_SECRETS:-$KIDS_OS_CONFIG/secrets.env}"
KIDS_OS_OUT="${KIDS_OS_OUT:-$HOME/kids-os-build}"
_kids_os_value() { if [ -f "$KIDS_OS_SECRETS" ]; then sed -n "s/^$1=//p" "$KIDS_OS_SECRETS" | tail -n 1; fi; }
ADMIN="${KIDS_OS_ADMIN_USER:-$(_kids_os_value KIDS_OS_ADMIN_USER)}"; ADMIN="${ADMIN:-admin}"
BOX="${KIDS_OS_HOST:-$(_kids_os_value KIDS_OS_HOST)}"
