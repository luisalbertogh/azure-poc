# =============================================================================
# REGION: westeurope (dev)
# =============================================================================
# Region-level variables. A single environment may span multiple regions by
# duplicating this structure under a sibling directory (e.g. northeurope/).
# =============================================================================

locals {
  location       = "spaincentral"
  location_short = "esc"   # Used in resource naming conventions
}
