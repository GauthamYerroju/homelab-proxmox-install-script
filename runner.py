#!/usr/bin/env python3
import argparse
import subprocess
import sys
import os

# ================== Terminal Colors & Emojis ==================
class Term:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    RESET = "\033[0m"
    BOLD = "\033[1m"

EMOJI_ENABLED = "✅"
EMOJI_DISABLED = "❌"
EMOJI_PROMPT = "⚠️"

# ================== Step Definitions ==================
STEPS = {
    "proxmox_post_install": {
        "desc": "Proxmox post-install",
        "depends": [],
        "script": "runner-steps/proxmox_post_install.sh"
    },
    "docker_vm": {
        "desc": "Install Docker VM",
        "depends": [],
        "script": "runner-steps/docker_vm.sh"
    },
    "set_swappiness": {
        "desc": "Set vm.swappiness",
        "depends": [],
        "script": "runner-steps/set_swappiness.sh"
    },
    "iommu": {
        "desc": "Enable IOMMU in GRUB",
        "depends": [],
        "script": "runner-steps/iommu.sh"
    },
    "vfio_modules": {
        "desc": "Load VFIO kernel modules",
        "depends": ["iommu"],
        "script": "runner-steps/vfio_modules.sh"
    },
    "pci_passthrough": {
        "desc": "PCI passthrough setup",
        "depends": ["iommu", "vfio_modules"],
        "script": "runner-steps/pci_passthrough.sh"
    },
}

# ================== Utility Functions ==================
def query_step_status(step):
    script = STEPS[step]["script"]
    return subprocess.call(f"bash -c 'source {script}; query'", shell=True, stdout=subprocess.DEVNULL) == 0

def run_step(step, enable=True, param="", dry_run=False, log=None):
    script = STEPS[step]["script"]
    action = "enable" if enable else "disable"
    cmd = f"bash -c 'source {script}; {action} {param}'"
    log_line = f"[DRY-RUN] {cmd}" if dry_run else cmd
    if log:
        log.write(log_line + "\n")
    if dry_run:
        print(f"{Term.YELLOW}{log_line}{Term.RESET}")
        return True
    ret = os.system(cmd)
    if ret != 0:
        print(f"{Term.RED}Step {step} failed{Term.RESET}")
        return False
    return True

def resolve_order(selected_steps):
    visited = set()
    order = []
    def visit(step):
        if step in visited or step not in selected_steps:
            return
        for dep in STEPS[step]["depends"]:
            visit(dep)
        visited.add(step)
        order.append(step)
    for s in selected_steps:
        visit(s)
    return order

def show_summary_table(status, desired):
    print(f"\n{Term.BOLD}Step Status Summary{Term.RESET}")
    print(f"{'Step':<25} {'Current':<10} {'Desired':<10}")
    print("-" * 50)
    for key in STEPS:
        cur = EMOJI_ENABLED if status[key] else EMOJI_DISABLED
        des = EMOJI_ENABLED if desired.get(key, False) else EMOJI_DISABLED
        print(f"{STEPS[key]['desc']:<25} {cur:<10} {des:<10}")
    print("")

# ================== Main ==================
def main():
    parser = argparse.ArgumentParser(description="Proxmox Idempotent Runner", epilog="Dry-run shows commands, plan-file writes bash script.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--plan-file", type=str, help="Write bash plan to file")
    parser.add_argument("--log-file", type=str, help="Optional log file of actions")
    args = parser.parse_args()

    log = open(args.log_file, "a") if args.log_file else None

    print(f"{Term.BOLD}{Term.YELLOW}⚡ Proxmox Idempotent Setup Runner ⚡{Term.RESET}\n")

    # Step 1: Query all steps
    current_status = {k: query_step_status(k) for k in STEPS}

    # Step 2: Prepare desired status dictionary with defaults
    desired = {}
    show_summary_table(current_status, desired)

    # Step 3: Prompt user
    for key, info in STEPS.items():
        cur = "enabled" if current_status[key] else "disabled"
        default_input = "y" if current_status[key] else "n"
        ans = input(f"{EMOJI_PROMPT} {info['desc']} [{cur}]? y/n: ").strip().lower()
        desired[key] = ans.startswith("y")

    show_summary_table(current_status, desired)

    confirm = input(f"{EMOJI_PROMPT} Proceed? [n]: ").strip().lower()
    if not confirm.startswith("y"):
        print("Aborting.")
        if log: log.close()
        sys.exit(0)

    steps_to_run = resolve_order([k for k, v in desired.items() if k in STEPS])

    # Step 4: Execute steps
    for s in steps_to_run:
        param = ""
        run_step(s, enable=desired[s], param=param, dry_run=args.dry_run, log=log)

    if log: log.close()
    print(f"\n{Term.GREEN}✅ All steps completed.{Term.RESET}")

if __name__ == "__main__":
    main()
