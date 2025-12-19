# e2etest-aws-foundation - Single Account Foundation with IPAM
# ===========================================================
# Creates a single-account Foundation with Identity Center and IPAM.
# Uses the same IPAM configuration as aws-ipam e2e test for shared resources.
#
# After first run, update externalName fields with actual IDs to import.
# Both this test and aws-ipam test should use the same resource IDs.
#
# Resources created:
# - Identity Center groups and permission sets (imported/persistent)
# - IPAM with dual-stack pools (shared with aws-ipam test):
#   - ipv4: 10.0.0.0/8 for VPC IPv4 CIDRs
#   - ipv6-public: Amazon-provided GUA for internet-routable workloads
#   - ipv6-private: fd00:hops::/48 ULA for internal services
#   - aws-foundation-<timestamp>: ephemeral test pool (deleted after test)

import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as hops
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_now = str(int(math.floor(datetime.ticks())))

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Configuration - aligned with aws-ipam e2e test
# =============================================================================

_foundation_name = "hops-e2e-foundation"
_region = "us-east-2"

# Orphan management policies - no Delete means resources persist
_persist = ["Create", "Observe", "Update", "LateInitialize"]

# Ephemeral test pool name - deleted after test
_test_pool_name = "aws-foundation-" + _now

# =============================================================================
# Existing resource IDs (update after first successful run)
# =============================================================================
# After running aws-ipam e2e test, get IDs with:
#   aws ec2 describe-ipams --query 'Ipams[*].[IpamId,Tags]'
#   aws ec2 describe-ipam-pools --query 'IpamPools[*].[IpamPoolId,Description]'
#   aws ec2 describe-ipam-pool-cidrs --ipam-pool-id <pool-id> --query 'IpamPoolCidrs[*].IpamPoolCidrId'
#
_ipam_external_name = "ipam-0573c7815d0a36e00"

# IPv4 pool (cidrExternalName format: cidr_pool-id)
_ipv4_pool_external_name = "ipam-pool-0a82c73b97dc0dabb"
_ipv4_cidr_external_name = "10.0.0.0/8" + "_" + _ipv4_pool_external_name

# IPv6 public pool - cidrExternalName format: cidr_pool-id
_ipv6_public_pool_external_name = "ipam-pool-06b3ec78deea8bcb9"
_ipv6_public_cidr_external_name = "2600:1f26:47:c000::/52" + "_" + _ipv6_public_pool_external_name

# IPv6 private pool (ULA) - cidrExternalName format: cidr_pool-id
_ipv6_private_pool_external_name = "ipam-pool-0decd6c5216660c74"
_ipv6_private_cidr_external_name = "fdc4:f045:5323::/48" + "_" + _ipv6_private_pool_external_name

# =============================================================================
# Identity Center - from existing setup (AWS only allows one per org/account)
# =============================================================================
# Get these values with: aws sso-admin list-instances
_identity_store_id = "d-9a675288a4"
_instance_arn = "arn:aws:sso:::instance/ssoins-668444b406cda8b2"

# Persistent Identity Center resources - imported via externalName
_persistent_group_name = "hops-e2e-test"
_persistent_group_id = "d1fb9590-0091-7072-55a4-dd0778f5d5cb"

_persistent_user_name = "hops-e2e-admin"
_persistent_user_id = "217be550-1051-7016-a428-1864e5e57e75"
_persistent_membership_id = "115b85b0-f0c1-70ae-802f-41695fa2f655"

_persistent_permission_set_name = "E2EPersistentAccess"
_persistent_permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-668444b406cda8b2/ps-aaebc62f1ea517cc"
_persistent_permission_set_external_name = _persistent_permission_set_arn + "," + _instance_arn

# Target account for permission set assignments
_target_account_id = "544051101726"

# =============================================================================
# E2E Test Definition
# =============================================================================

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                hops.Foundation{
                    metadata: {
                        name: _foundation_name
                        namespace: "default"
                    }
                    spec: {
                        managementPolicies: _persist

                        aws: {
                            providerConfig: "default"
                            region: _region
                        }

                        tags: {
                            "e2etest": "true"
                            "managed-by": "crossplane"
                        }

                        # -----------------------------------------------------------------
                        # Identity Center - import existing
                        # -----------------------------------------------------------------
                        identityCenter: {
                            region: _region
                            identityStoreId: _identity_store_id
                            instanceArn: _instance_arn
                            sessionDuration: "PT4H"

                            groups: [
                                {
                                    name: _persistent_group_name
                                    displayName: "E2E Test Admins"
                                    externalName: _persistent_group_id
                                    managementPolicies: _persist
                                }
                            ]

                            users: [
                                {
                                    username: _persistent_user_name
                                    email: "hops-e2e-admin@ops.com.ai"
                                    firstName: "E2E"
                                    lastName: "Admin"
                                    externalName: _persistent_user_id
                                    managementPolicies: _persist
                                    groups: [_persistent_group_name]
                                    groupMembershipExternalNames: {
                                        (_persistent_group_name): _persistent_membership_id
                                    }
                                }
                            ]

                            permissionSets: [
                                {
                                    name: _persistent_permission_set_name
                                    description: "E2E testing read-only access"
                                    externalName: _persistent_permission_set_external_name
                                    managementPolicies: _persist
                                    managedPolicies: [
                                        "arn:aws:iam::aws:policy/ReadOnlyAccess"
                                    ]
                                    assignToGroups: [_persistent_group_name]
                                    assignToAccounts: [_target_account_id]
                                }
                            ]
                        }

                        # -----------------------------------------------------------------
                        # IPAM - same config as aws-ipam e2e test
                        # -----------------------------------------------------------------
                        ipam: {
                            enabled: True
                            scope: "private"
                            homeRegion: _region
                            operatingRegions: [_region]
                            managementPolicies: _persist
                            if _ipam_external_name:
                                externalName: _ipam_external_name

                            pools: [
                                # IPv4 pool for VPCs
                                {
                                    name: "ipv4"
                                    addressFamily: "ipv4"
                                    region: _region
                                    cidr: "10.0.0.0/8"
                                    managementPolicies: _persist
                                    if _ipv4_pool_external_name:
                                        externalName: _ipv4_pool_external_name
                                    if _ipv4_cidr_external_name:
                                        cidrExternalName: _ipv4_cidr_external_name
                                    allocationDefaultNetmaskLength: 20
                                    allocationMinNetmaskLength: 16
                                    allocationMaxNetmaskLength: 24
                                    description: "IPv4 pool for VPCs"
                                    labels: {
                                        "address-family": "ipv4"
                                    }
                                    tags: {
                                        purpose: "vpc-ipv4"
                                    }
                                },
                                # IPv6 Public Pool (Amazon-provided GUA)
                                {
                                    name: "ipv6-public"
                                    addressFamily: "ipv6"
                                    scope: "public"
                                    region: _region
                                    locale: _region
                                    amazonProvidedIpv6CidrBlock: True
                                    publicIpSource: "amazon"
                                    awsService: "ec2"
                                    netmaskLength: 52  # AWS provisions /52 GUA block (16 x /56 VPC allocations)
                                    managementPolicies: _persist
                                    if _ipv6_public_pool_external_name:
                                        externalName: _ipv6_public_pool_external_name
                                    if _ipv6_public_cidr_external_name:
                                        cidrExternalName: _ipv6_public_cidr_external_name
                                    allocationDefaultNetmaskLength: 56
                                    allocationMinNetmaskLength: 52
                                    allocationMaxNetmaskLength: 60
                                    description: "Public IPv6 pool (Amazon GUA)"
                                    labels: {
                                        "address-family": "ipv6"
                                        "ipv6-type": "public"
                                    }
                                    tags: {
                                        purpose: "vpc-ipv6-public"
                                    }
                                },
                                # IPv6 Private Pool (ULA - AWS auto-assigns from fd00::/8)
                                {
                                    name: "ipv6-private"
                                    addressFamily: "ipv6"
                                    scope: "private"
                                    region: _region
                                    locale: _region
                                    netmaskLength: 48  # AWS auto-assigns ULA CIDR
                                    managementPolicies: _persist
                                    if _ipv6_private_pool_external_name:
                                        externalName: _ipv6_private_pool_external_name
                                    if _ipv6_private_cidr_external_name:
                                        cidrExternalName: _ipv6_private_cidr_external_name
                                    allocationDefaultNetmaskLength: 56
                                    allocationMinNetmaskLength: 48
                                    allocationMaxNetmaskLength: 64
                                    description: "Private IPv6 pool (ULA)"
                                    labels: {
                                        "address-family": "ipv6"
                                        "ipv6-type": "private"
                                    }
                                    tags: {
                                        purpose: "vpc-ipv6-private"
                                    }
                                },
                                # Ephemeral test pool - deleted after test run
                                {
                                    name: _test_pool_name
                                    addressFamily: "ipv4"
                                    region: _region
                                    cidr: "172.31.0.0/16"
                                    # Full management - gets deleted
                                    managementPolicies: ["*"]
                                    allocationDefaultNetmaskLength: 24
                                    allocationMinNetmaskLength: 20
                                    allocationMaxNetmaskLength: 28
                                    description: "Ephemeral test pool - " + _test_pool_name
                                    labels: {
                                        "ephemeral": "true"
                                        "test-run": _now
                                    }
                                    tags: {
                                        purpose: "e2e-test"
                                        "test-run": _now
                                    }
                                }
                            ]
                        }
                    }
                }
            ]
            extraResources: [
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata: {
                        name: "aws-creds"
                        namespace: "default"
                    }
                    data: {
                        creds: _base64_creds
                    }
                },
                {
                    apiVersion: "aws.m.upbound.io/v1beta1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: "default"
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "Secret"
                            secretRef: {
                                namespace: "default"
                                name: "aws-creds"
                                key: "creds"
                            }
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 5400
        }
    }
]
items = _items
