# =============================================================================
# WORKSPACE-LEVEL TERRAGRUNT CONFIGURATION
# =============================================================================
# This optional root-level terragrunt.hcl allows running commands from the
# repository root. It is intentionally minimal – all real configuration lives
# in root.hcl which is discovered via find_in_parent_folders() by each unit.
#
# Running from here:
#   terragrunt run --all plan              – plan every unit in the repo
#   terragrunt run --all apply             – apply every unit in the repo
#   terragrunt run --all apply --queue-include-units-reading=env.hcl \
#     --queue-include-dir environments/dev – apply only the dev environment
# =============================================================================

# No-op: real configuration is in root.hcl
