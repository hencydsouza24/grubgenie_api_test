# Back-compat shim — see pos.ps1. Usage: pwsh ./test_pos_validation.ps1
# Spawns pos.ps1 as a real subprocess — NOT `&` or dot-source, both of which swallow a nested
# script's `exit` (see order_item.ps1 for the usual thin, in-process shim pattern). validate's
# logic is large enough that duplicating it here would leave two copies to keep in sync; the
# ~100ms subprocess cost is the better trade for a back-compat shim that isn't in anyone's hot
# path.
& pwsh -NoProfile -File "$PSScriptRoot/pos.ps1" validate @args
exit $LASTEXITCODE
