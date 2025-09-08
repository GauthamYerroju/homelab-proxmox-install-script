#!/bin/bash

# ================== Instructions ==============================
# 1. Set defaults / parameters (e.g., swappiness value, PCI IDs).
# 2. Define enable() - implement step logic, accept parameters.
# 3. Define disable() - implement undo logic.
# 4. Define query() - return 0 if enabled, 1 if disabled.
# 5. Ensure idempotency - repeated calls should not break system.
# 6. Python runner calls: "source script; enable/disable/query".
# 7. Keep consistent function names across all step scripts.
#===============================================================

# ================== Configuration / Defaults ==================
# e.g., for swappiness or PCI IDs
PARAM_DEFAULT=""

# ================== Functions ==================
function enable() {
    local param="$1"
    # Use $param if provided, otherwise fallback to default
    echo "Enabling STEP_NAME with param: ${param:-$PARAM_DEFAULT}"
    # Actual enable logic goes here
}

function disable() {
    echo "Disabling STEP_NAME"
    # Actual disable logic goes here
}

function query() {
    # Return 0 if enabled, 1 if disabled
    return 1
}
