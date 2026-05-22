# Forge LZ Starter — Azure Landing Zone

*[Forge LZ Starter on Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=frametype)*

---

<!-- consumed-by: web | field: purpose -->
### Purpose

This offer deploys a fully configured, CAF-aligned Azure Landing Zone into a single Azure subscription directly from the Azure Marketplace. It is designed for organizations that want a production-grade cloud foundation without the complexity of building landing zone infrastructure from scratch.

<!-- consumed-by: web | field: outcomes -->
Key outcomes this offer delivers:

1. **CAF-Aligned Foundation:** Five resource groups structured around Cloud Adoption Framework separation principles — management, networking, security, identity, and workload — with consistent naming and tagging from day one.

2. **Hub-Spoke Networking Ready:** A hub and spoke VNet topology with NSGs, route tables, and peering configured at deployment. The routing layer is upgrade-ready for Azure Firewall (Forge Connect, Tier 2) without replacement of existing infrastructure.

3. **Zero Trust by Design:** Outbound internet traffic restricted to HTTPS only, no public IPs on platform resources, PIM-eligible JIT managed service access with MFA, and Key Vault protected with a CanNotDelete lock. See the [Zero Trust Alignment](#zero-trust-alignment) section for a full principle mapping.

4. **Governance from Day One:** Azure Policy for backup and Defender for Servers, RBAC assignments for two customer-defined Entra ID groups, budget alerts, and diagnostic settings routing platform telemetry to Log Analytics — all configured at deployment time.

5. **frameType Managed Service:** Azure Lighthouse delegation gives frameType Solutions read access for monitoring and JIT Contributor access (PIM-eligible, MFA required, 8-hour maximum) for support and operations — without standing access to your subscription.

<!-- consumed-by: web | field: scope -->
### Scope

This offer deploys a single-subscription Tier 1 Azure Landing Zone with a hub-spoke network topology. It is designed for organizations deploying into a new or dedicated Azure subscription and is intended to be extended to production workloads.

**Not included in Tier 1:**
- Azure Firewall (available in Forge Connect, Tier 2)
- Management Group hierarchy (recommended pre-deployment configuration — see pre-deployment guidance)
- VPN Gateway or ExpressRoute connectivity
- Private DNS zones for PaaS services (Tier 2+)
- NSG flow logs (Tier 2+)
- Hybrid identity or domain join

---

## Table of Contents

- [Overview](#overview)
- [Azure Pricing](#azure-pricing)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Zero Trust Alignment](#zero-trust-alignment)
- [Azure Governance](#azure-governance)
- [Naming Conventions](#naming-conventions)
- [Identity and RBAC](#identity-and-rbac)
- [Managed Service Access](#managed-service-access)
- [Troubleshooting](#troubleshooting)
- [Upgrade Path](#upgrade-path)
- [Conclusion](#conclusion)
- [References](#references)

---

## Overview

### Architecture Overview

*Architecture diagram — coming at release.*

### Components

All resources are provisioned into the managed resource group and its five child resource groups.

| Resource | Type | Resource Group |
|---|---|---|
| `law-alz-{env}-{region}-01` | Log Analytics Workspace | `rg-alz-management` |
| `aa-alz-{env}-{region}-01` | Automation Account | `rg-alz-management` |
| `mc-alz-{env}-{region}-01` | Maintenance Configuration | `rg-alz-management` |
| `rsv-alz-{env}-{region}-01` | Recovery Services Vault | `rg-alz-management` |
| `bvault-alz-{env}-{region}-01` | Backup Vault | `rg-alz-management` |
| `budget-alz-{env}-{region}-01` | Cost Management Budget | `rg-alz-management` |
| `vnet-alz-hub-{env}-{region}-01` | Virtual Network (hub) | `rg-alz-networking` |
| `vnet-alz-spoke-{env}-{region}-01` | Virtual Network (spoke) | `rg-alz-networking` |
| `nsg-alz-{env}-{region}-01` | Network Security Group | `rg-alz-networking` |
| `rt-alz-{env}-{region}-01` | Route Table | `rg-alz-networking` |
| `kv-alz-{env}-{region}-01` | Key Vault | `rg-alz-security` |
| Policy assignments | Azure Policy | Subscription / RG scope |
| RBAC assignments | Role assignments | Per resource group |
| Lighthouse registration | Azure Lighthouse | Subscription scope |

---

## Azure Pricing

Forge LZ Starter deploys infrastructure components that incur Azure consumption charges billed directly to your subscription. The Marketplace subscription fee covers frameType managed service access (monitoring and JIT support).

| Component | Estimated monthly cost | Notes |
|---|---|---|
| Log Analytics Workspace | $2.30–$5.00/GB ingested | Varies by log volume; platform telemetry only at Tier 1 |
| Automation Account | ~$0 (free tier for basic use) | Run As Account not required |
| Recovery Services Vault | $0 (no protected items at deployment) | Backup policy ready — costs begin when VMs are protected |
| Backup Vault | $0 (no protected items at deployment) | |
| Key Vault | ~$0.03/10,000 operations | Minimal at platform-only usage |
| VNets and peering | ~$1–$5/month | Peering cost depends on egress traffic volume |
| Budget alerts | $0 | Cost Management feature — no charge |
| Defender for Cloud (Basic) | $0 | Basic tier is free |
| Defender for Cloud (Standard/Enhanced) | Per-resource pricing | See [Defender for Cloud pricing](https://azure.microsoft.com/en-us/pricing/details/defender-for-cloud/) |
| Marketplace subscription fee | See listing | frameType managed service |

Estimate total costs using the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/).

---

## Prerequisites

Complete the following before beginning the Marketplace deployment wizard.

| Prerequisite | Details |
|---|---|
| Azure subscription | A new or dedicated subscription is strongly recommended. The offer deploys at subscription scope. |
| Subscription Owner | The deploying account must hold Owner on the target subscription — required for Lighthouse and RBAC assignments. |
| Entra ID permissions | Global Administrator, Groups Administrator, or User Administrator — required to run the pre-deployment script. |
| PowerShell 7 | Required to run `alzPreDeployment.ps1`. Download: https://aka.ms/install-powershell |
| Azure CLI | Required by the pre-deployment script. Download: https://aka.ms/installazurecli |
| Address space planning | Two non-overlapping RFC1918 /16 blocks — one for the hub VNet, one for the spoke VNet. Default: `10.0.0.0/16` (hub) and `10.10.0.0/16` (spoke). |
| Marketplace access | The deploying account must have access to Azure Marketplace in the target subscription. |

---

## Deployment Steps

```
Step 1 — Run pre-deployment script   →   Step 2 — Deploy from Marketplace   →   Step 3 — Verify and onboard users
```

---

### Step 1 — Run the Pre-Deployment Script (REQUIRED BEFORE MARKETPLACE WIZARD)

The Marketplace deployment wizard requires the **Object IDs of two Entra ID security groups** on the Identity & Access step. These groups must exist in your tenant before you begin the wizard.

The pre-deployment script creates both groups (or retrieves them if they already exist) and displays the Object IDs ready to paste into the wizard.

Download and run the script from PowerShell 7:

```powershell
# Download the script
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/frametypeSolutions/msMarketplaceOffer-azureLandingZoneStarter/main/preDeploymentScripts/alzPreDeployment.ps1" `
  -OutFile ".\alzPreDeployment.ps1"

# Unblock the downloaded file
Unblock-File .\alzPreDeployment.ps1

# Run the script
.\alzPreDeployment.ps1
```

With custom group names (recommended — include an environment suffix):

```powershell
.\alzPreDeployment.ps1 `
    -PlatformAdminGroupName "grp-alz-platform-admins-prod" `
    -WorkloadAdminGroupName "grp-alz-workload-admins-prod"
```

On completion, the script displays:

```
================================================================
  Forge LZ Starter — Pre-Deployment Complete
================================================================

  Copy these Object IDs into the deployment wizard.
  You will be prompted for them in the Identity & Access step.

  Platform Admin Group Object ID
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

  Workload Admin Group Object ID
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

================================================================
```

Copy both Object IDs — you will need them in Step 2.

> **Permissions required:** The account running this script must hold one of **Global Administrator**, **Groups Administrator**, or **User Administrator** in Entra ID.

> **Idempotent:** If the groups already exist, the script retrieves and reuses them. It is safe to run multiple times.

---

### Step 2 — Deploy from Azure Marketplace

1. Find **Forge LZ Starter** in [Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=frametype)
2. Click **Get It Now** and follow the deployment wizard
3. Complete the **Basics** page and seven configuration steps:

**Basics — Managed Application Setup**

Use CAF-aligned values for all three naming fields rather than the portal-generated defaults:

| Field | Recommended format | Example |
|---|---|---|
| Resource group | `rg-alz-{env}-{region}-managed` | `rg-alz-prod-eastus-managed` |
| Application Name | `app-forge-lz-{env}-{region}` | `app-forge-lz-prod-eastus` |
| Managed Resource Group | `mrg-alz-{env}-{region}-01` | `mrg-alz-prod-eastus-01` |

**Step 1 — Prerequisites:** Checklist confirmation — no values entered.

**Step 2 — Environment:**

| Field | Options | Default |
|---|---|---|
| Environment | `prod`, `dev`, `test`, `infra` | `prod` |
| Hub VNet address space | RFC1918 /16 block | `10.0.0.0/16` |
| Spoke VNet address space | RFC1918 /16 block | `10.10.0.0/16` |

**Step 3 — Identity Prerequisites:** Informational — review group guidance and confirm the pre-deployment script has been run.

**Step 4 — Identity & Access:** Paste the two Object IDs from the pre-deployment script output.

**Step 5 — Security:** Select Defender for Cloud tier (Basic / Standard / Enhanced).

**Step 6 — Governance & Cost:**

| Field | Description |
|---|---|
| Landing zone owner email | Applied as `owner` tag on all resource groups |
| Cost center code | Applied as `costCenter` tag on all resource groups |
| Monthly budget | Notification threshold $100–$50,000; default $500 |
| Budget alert email | Defaults to owner email — override for a shared ops mailbox |

**Step 7 — Post-Deployment Steps:** Review the post-deployment checklist before clicking **Create**.

4. Deployment typically completes in **15–20 minutes**

---

### Step 3 — Verify and Onboard Users

After the Marketplace deployment completes, complete the [Post-Deployment Verification](#post-deployment-verification) checklist, then add users to the Entra ID security groups:

- **Platform Admins group** — platform and security operations personnel
- **Workload Admins group** — application and workload deployment teams

---

## Post-Deployment Verification

Forge LZ Starter is fully automated — no mandatory post-deployment configuration is required. Complete the following verification steps after deployment succeeds.

**Step 1 — Verify resource group deployment**

Navigate to **Azure Portal → Resource groups**. Confirm all five resource groups exist with `Succeeded` provisioning state:

- `rg-alz-management-{environment}-{region}-01`
- `rg-alz-networking-{environment}-{region}-01`
- `rg-alz-security-{environment}-{region}-01`
- `rg-alz-identity-{environment}-{region}-01`
- `rg-alz-workload-{environment}-{region}-01`

**Step 2 — Verify Lighthouse delegation**

Navigate to **Azure Portal → Azure Lighthouse → Service providers → Service provider offers**. Forge LZ Starter should appear with five active resource group delegations. If delegations are missing after 30 minutes, check the `deploymentScript` resource in the managed resource group for errors and contact frameType Solutions support.

**Step 3 — Verify RBAC assignments**

Navigate to each resource group → **Access control (IAM) → Role assignments**. Confirm the following assignments are present:

| Group | Role | Resource group |
|---|---|---|
| Platform Admins | Reader | `rg-alz-management`, `rg-alz-networking`, `rg-alz-security` |
| Platform Admins | Key Vault Secrets Officer | `rg-alz-security` |
| Workload Admins | Contributor | `rg-alz-workload` |
| Workload Admins | Key Vault Reader | `rg-alz-security` |

**Step 4 — Review Defender for Cloud recommendations**

Navigate to **Azure Portal → Microsoft Defender for Cloud → Recommendations**. The Azure Security Benchmark policy begins evaluating your environment shortly after deployment. Initial results may take 15–30 minutes to populate. Review high-severity recommendations first.

**Step 5 — Populate Entra ID security groups with members**

RBAC roles have been assigned to the groups automatically — users still need to be added. Navigate to **Azure Portal → Microsoft Entra ID → Groups → [select group] → Members → Add members**. Repeat for both the Platform Admins and Workload Admins groups.

---

## Zero Trust Alignment

<!-- consumed-by: web | field: zeroTrust -->
Forge LZ Starter is designed around Microsoft's Zero Trust security principles. Every architectural decision maps to one or more of the three core principles: **Verify Explicitly**, **Use Least Privilege**, and **Assume Breach**.

| Principle | Implementation |
|---|---|
| **Verify Explicitly** | All access to landing zone resources is controlled via Entra ID group membership and Azure RBAC — no shared credentials or standing access outside defined roles. Lighthouse MFA is required for every PIM activation before write access is granted. Defender for Cloud Basic evaluates configuration continuously against the Azure Security Benchmark policy. |
| **Use Least Privilege** | Platform Admins receive Reader only on infrastructure resource groups — no write capability. Workload Admins receive Contributor on the workload RG only — not subscription-wide. Key Vault access is split: Secrets Officer for platform (management plane) and Reader for workload (data plane retrieval only). frameType holds Reader permanently and Contributor only via PIM activation with an 8-hour maximum duration. |
| **Assume Breach** | Outbound internet traffic is restricted to port 443 only at the NSG level. No public IP addresses are deployed on platform resources. Diagnostic settings route all platform telemetry to Log Analytics for centralized visibility. The routing layer is pre-staged for Azure Firewall (Forge Connect, Tier 2) — enabling deep packet inspection and threat intelligence-based filtering when added. |

### Networking

- NSG outbound rules restrict internet egress to HTTPS (port 443) only
- No `0.0.0.0/0` default route at Tier 1 — RFC1918 summary routes use `VnetLocal` next hop
- Route table is upgrade-ready: Forge Connect populates the default route with the Azure Firewall private IP without replacing existing infrastructure
- No public IP addresses on platform resources

### Identity

- All administrative access is group-based — no direct user assignments
- frameType JIT access requires PIM activation, MFA, and has an 8-hour maximum duration
- Lighthouse delegation is revocable at any time from **Azure Portal → Lighthouse → Service provider offers → Delete**

---

## Azure Governance

Forge LZ Starter implements CAF and WAF guidance through automated policy and consistent resource configuration.

| Control | Implementation |
|---|---|
| Resource tagging | `environment`, `workload`, `owner`, `costCenter` tags applied to all resource groups at deployment |
| Backup policy | DINE policy assigns Azure Backup to all VMs in `rg-alz-workload` automatically |
| Defender for Servers | DINE policy deploys Defender for Servers to `rg-alz-workload` (Standard/Enhanced tiers) |
| Update management | Azure Update Manager maintenance configuration targets `rg-alz-workload` |
| Cost alerting | Budget with configurable threshold and email alerts |
| Diagnostic settings | Platform resource logs routed to Log Analytics at deployment |

---

## Naming Conventions

All resources follow the [CAF naming convention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming):

```
{resource-type}-{workload}-{environment}-{region}-{instance}
```

| Token | Value | Example |
|---|---|---|
| `{resource-type}` | CAF abbreviation | `vnet`, `nsg`, `kv`, `law` |
| `{workload}` | `alz` (hardcoded) | `alz` |
| `{environment}` | Wizard input | `prod`, `dev`, `test`, `infra` |
| `{region}` | Full Azure region name | `eastus`, `westus2` |
| `{instance}` | Zero-padded sequence | `01` |

**Examples:**

| Resource | Name |
|---|---|
| Log Analytics Workspace | `law-alz-prod-eastus-01` |
| Hub VNet | `vnet-alz-hub-prod-eastus-01` |
| Key Vault | `kv-alz-prod-eastus-01` |
| Management RG | `rg-alz-management-prod-eastus-01` |

---

## Identity and RBAC

| Principal | Type | Scope | Role |
|---|---|---|---|
| Platform Admins group | Customer Entra group | `rg-alz-management` | Reader |
| Platform Admins group | Customer Entra group | `rg-alz-networking` | Reader |
| Platform Admins group | Customer Entra group | `rg-alz-security` | Reader |
| Platform Admins group | Customer Entra group | `rg-alz-security` | Key Vault Secrets Officer |
| Workload Admins group | Customer Entra group | `rg-alz-workload` | Contributor |
| Workload Admins group | Customer Entra group | `rg-alz-security` | Key Vault Reader |
| Policy Identity | Managed identity | `rg-alz-management` | Contributor (policy remediation) |
| frameType lighthouseReaders | frameType Entra group | Five operational RGs | Reader (permanent) |
| frameType lighthouseEngineers | frameType Entra group | Five operational RGs | Contributor (PIM-eligible, 8hr max) |

---

## Managed Service Access

Forge LZ Starter includes Azure Lighthouse delegation to frameType Solutions as part of the offer.

| Access type | Mechanism | Scope |
|---|---|---|
| Monitoring (read) | Permanent Reader | Five operational resource groups |
| Support / operations (write) | PIM-eligible Contributor — MFA required, 8-hour maximum | Five operational resource groups |

**What frameType can access:** Resources within the five operational resource groups (`rg-alz-management`, `rg-alz-networking`, `rg-alz-security`, `rg-alz-identity`, `rg-alz-workload`). No access to other subscriptions, tenants, or resources outside these groups.

**What frameType cannot access:** Your Entra ID tenant, other subscriptions, resource groups not listed above, or any data stored within your resources.

**Revoking access:** Navigate to **Azure Portal → Azure Lighthouse → Service providers → Service provider offers → Forge LZ Starter → Delete**. Delegation is revoked immediately.

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Pre-deployment script fails with permission error | Account lacks Entra ID group creation rights | Confirm the account holds Global Administrator, Groups Administrator, or User Administrator. Re-run the script with an eligible account. |
| Wizard Identity & Access step rejects Object IDs | Object IDs are from a different tenant, or contain extra whitespace | Copy Object IDs directly from the script output. Confirm the groups exist in the same tenant as the target subscription. |
| Deployment fails at Lighthouse registration | deploymentScript managed identity lacks required permissions | The managed identity requires `Microsoft.ManagedServices/registrationAssignments/write` at subscription scope. This is included in the Owner role — confirm the deploying account holds Owner. |
| Lighthouse delegation missing after 30 minutes | deploymentScript execution failed silently | Navigate to **Azure Portal → Resource groups → mrg-{name} → Deployments**. Inspect the `deploymentScript` resource and review the execution log for errors. |
| RBAC assignments not visible after deployment | Propagation delay | Azure RBAC assignments can take up to 5 minutes to propagate. Refresh the IAM blade and confirm group membership. |
| Defender for Cloud recommendations missing | Policy evaluation lag | Initial evaluation after deployment can take 15–30 minutes. Navigate to **Defender for Cloud → Recommendations** and trigger a manual assessment if needed. |

---

## Upgrade Path

| Tier | Offer | What it adds |
|---|---|---|
| **Tier 1 — this offer** | Forge LZ Starter | Single-subscription landing zone, hub-spoke networking, Zero Trust baseline, governance, Lighthouse managed service |
| **Tier 2** | Forge Connect | Azure Firewall, default route population, Private DNS zones, NSG flow logs, multi-subscription peering |
| **Tier 3** | Forge Enterprise | Management Group hierarchy, cross-subscription governance, enterprise-scale policy initiative |

The Tier 1 route table and subnet configuration are upgrade-ready — Forge Connect extends the existing infrastructure rather than replacing it.

---

## Conclusion

Forge LZ Starter provides a production-grade, CAF-aligned Azure Landing Zone foundation for organizations beginning their Azure journey or formalizing an existing subscription. The deployment is repeatable, governed by Microsoft framework guidance, and architecturally designed for growth — the Forge Connect and Enterprise tiers extend this foundation without replacement of existing infrastructure.

For questions or support, contact [frameType Solutions](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=frametype).

---

## References

| Resource | URL |
|---|---|
| Cloud Adoption Framework | https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ |
| CAF Naming Conventions | https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming |
| CAF Resource Abbreviations | https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations |
| Well-Architected Framework | https://learn.microsoft.com/en-us/azure/well-architected/ |
| Zero Trust for Azure IaaS | https://learn.microsoft.com/en-us/security/zero-trust/azure-infrastructure-overview |
| Azure Lighthouse documentation | https://learn.microsoft.com/en-us/azure/lighthouse/ |
| Azure Policy documentation | https://learn.microsoft.com/en-us/azure/governance/policy/ |
| RBAC Best Practices | https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices |
| Defender for Cloud pricing | https://azure.microsoft.com/en-us/pricing/details/defender-for-cloud/ |
| Azure Cost Management | https://learn.microsoft.com/en-us/azure/cost-management-billing/ |
| Azure Pricing Calculator | https://azure.microsoft.com/en-us/pricing/calculator/ |
| frameType Solutions on Marketplace | https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=frametype |

---

*Version 1.0 | frameType Solutions | May 2026*
