import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# =============================================================================
# Unit Tests for Foundation XRD
# =============================================================================
# These tests focus on behavioral validation of the Foundation XRD's API.
# render/validate already checks that composed resources have valid schemas.
# These tests verify YOUR API produces expected behavior:
# - Conditional rendering (when flag X is set, resources render)
# - Configuration mapping (when flag Y is set, resource configured correctly)
# - Default values (when field Z is omitted, defaults applied)
# - Edge cases (when A and B interact, expected output)

_items = [
    # =========================================================================
    # Conditional Rendering: Identity Center
    # =========================================================================
    # When identityCenter.identityStoreId is set, IdentityCenter XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-identity-center-renders-when-configured"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-ic"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                        groups = [{name = "Admins", description = "Admin group"}]
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-ic-identity-center"
                    spec.identityStoreId = "d-test123"
                }
            ]
        }
    },

    # =========================================================================
    # Conditional Rendering: IPAM
    # =========================================================================
    # When ipam.pools are defined, IPAM XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-ipam-renders-when-pools-defined"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-ipam"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    ipam = {
                        operatingRegions = ["us-east-1"]
                        pools = {
                            ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata.name = "test-ipam-ipam"
                    spec.operatingRegions = ["us-east-1"]
                }
            ]
        }
    },

    # =========================================================================
    # Conditional Rendering: Organization
    # =========================================================================
    # When organizationalUnits are defined, Organization XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-organization-renders-when-ous-defined"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-org"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    organizationalUnits = [{path = "TestOU"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata.name = "test-org"
                }
            ]
        }
    },

    # =========================================================================
    # Default Values: Region defaults to us-east-1
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-region-defaults-to-us-east-1"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-defaults"
                spec = {
                    managementPolicies = ["*"]
                    # region is omitted - should default to us-east-1
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-defaults-identity-center"
                    spec.region = "us-east-1"
                }
            ]
        }
    },

    # =========================================================================
    # Default Values: hops=true tag always applied
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-default-hops-tag-applied"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-tags"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    tags = {"custom-tag" = "custom-value"}
                    organizationalUnits = [{path = "Test"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata.name = "test-tags"
                    spec.tags = {
                        hops = "true"
                        "custom-tag" = "custom-value"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: Account names resolved to IDs
    # =========================================================================
    # When Organization status has accounts, permission set assignToAccounts
    # resolves account names to account IDs

    metav1alpha1.CompositionTest{
        metadata.name = "test-account-names-resolved-to-ids"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-resolve"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    organizationalUnits = [{path = "Teams"}]
                    accounts = [{name = "team-alpha", email = "alpha@test.com", ou = "Teams"}]
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                        groups = [{name = "TeamAlpha"}]
                        permissionSets = [{
                            name = "AlphaAccess"
                            managedPolicies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
                            assignToGroups = ["TeamAlpha"]
                            assignToAccounts = ["team-alpha"]
                        }]
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata = {
                        name = "test-resolve"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "organization"
                        }
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        accounts = [{name = "team-alpha", id = "123456789012", ready = True}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-resolve-identity-center"
                    spec.permissionSets = [{
                        name = "AlphaAccess"
                        assignToAccounts = ["123456789012"]
                    }]
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: ProviderConfigRef inheritance
    # =========================================================================
    # Child XRDs inherit providerConfigRef from Foundation

    metav1alpha1.CompositionTest{
        metadata.name = "test-provider-config-inherited"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-provider"
                spec = {
                    managementPolicies = ["*"]
                    providerConfigRef = {
                        name = "custom-provider"
                        kind = "ProviderConfig"
                    }
                    region = "us-west-2"
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-provider-identity-center"
                    spec.providerConfigRef = {
                        name = "custom-provider"
                        kind = "ProviderConfig"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: memberAccountsProviderConfigs.managementPolicies
    # =========================================================================
    # Account ProviderConfig Objects get their own managementPolicies

    metav1alpha1.CompositionTest{
        metadata.name = "test-account-providerconfigs-management-policies"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = False  # Uses Kubernetes Object which may not validate
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-mgmt"
                spec = {
                    managementPolicies = ["Observe"]
                    region = "us-east-1"
                    memberAccountsProviderConfigs = {
                        managementPolicies = ["*"]
                    }
                    organizationalUnits = [{path = "Test"}]
                    accounts = [{name = "test-account", email = "test@example.com", ou = "Test"}]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata = {
                        name = "test-mgmt"
                        annotations = {"crossplane.io/composition-resource-name" = "organization"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        accounts = [{name = "test-account", id = "222222222222", ready = True}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "test-mgmt-pc-test-account"
                    spec.managementPolicies = ["*"]
                }
            ]
        }
    },

    # =========================================================================
    # Edge Case: Networks don't render until IPAM pools are resolved
    # =========================================================================
    # Networks with poolRef wait for IPAM status to provide pool IDs

    metav1alpha1.CompositionTest{
        metadata.name = "test-networks-wait-for-ipam-pool-ids"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-net"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    ipam = {
                        pools = {
                            ipv4 = [{name = "ipv4-pool", cidr = "10.0.0.0/8"}]
                        }
                    }
                    networks = [{
                        name = "main"
                        region = "us-east-1"
                        ipam = {ipv4 = {poolRef = "ipv4-pool", netmaskLength = 16}}
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-net-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools = {
                            ipv4 = [{name = "ipv4-pool", id = "ipam-pool-abc123"}]
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-net-main"
                    spec.ipam.ipv4.poolId = "ipam-pool-abc123"
                }
            ]
        }
    }
]

items = _items
