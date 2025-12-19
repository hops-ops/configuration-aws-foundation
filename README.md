# configuration-aws-foundation

Foundation provides a single resource to manage your entire AWS foundation, from solo developer to enterprise. Start simple and evolve as you grow.

## The Journey

### Stage 1: Individual Developer

You have one AWS account. You want SSO access and organized IP allocation for your VPCs.

**What you need:**
- Identity Center for SSO (stop using IAM users)
- IPAM for automatic VPC CIDR allocation (no more spreadsheets)

**Why Identity Center?**
- Federate with Google/Okta/Azure AD later without changing anything
- Time-limited credentials (no long-lived access keys)
- Single place to manage who has access to what

**Why IPAM?**
- Request CIDRs from pools instead of manually tracking ranges
- Dual-stack ready (IPv4 + IPv6) for modern workloads
- When you add accounts later, VPCs won't overlap

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: my-foundation
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: default
    region: us-east-1

  # SSO access - get identityStoreId and instanceArn from AWS SSO console
  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: Administrators
        description: Full admin access

    permissionSets:
      - name: AdministratorAccess
        sessionDuration: PT4H  # 4 hour sessions
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess

  # IP address management - dual-stack for modern workloads
  ipam:
    scope: private
    homeRegion: us-east-1
    operatingRegions: [us-east-1]

    pools:
      # IPv4 for VPCs - 10.0.0.0/8 gives you 16 million addresses
      - name: ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        allocationDefaultNetmaskLength: 20  # /20 = 4096 IPs per VPC

      # IPv6 public - Amazon provides /52, you allocate /56 per VPC
      # Enables dual-stack networking for modern workloads
      - name: ipv6-public
        addressFamily: ipv6
        scope: public
        region: us-east-1
        locale: us-east-1
        amazonProvidedIpv6CidrBlock: true
        publicIpSource: amazon
        awsService: ec2
        allocationDefaultNetmaskLength: 56
```

### Stage 2: Small Team

You're hiring. You need different access levels and maybe a separate dev environment.

**What changes:**
- Add groups for different roles (Developers, ReadOnly)
- Add more permission sets with appropriate policies
- Consider adding a second AWS account for dev/staging

```yaml
# Add to identityCenter section:
groups:
  - name: Administrators
    description: Full admin access
  - name: Developers
    description: Can deploy and debug, no IAM changes
  - name: ReadOnly
    description: View resources only

permissionSets:
  - name: AdministratorAccess
    sessionDuration: PT4H
    managedPolicies:
      - arn:aws:iam::aws:policy/AdministratorAccess

  - name: PowerUserAccess
    sessionDuration: PT8H  # Longer sessions for developers
    managedPolicies:
      - arn:aws:iam::aws:policy/PowerUserAccess

  - name: ViewOnlyAccess
    sessionDuration: PT1H
    managedPolicies:
      - arn:aws:iam::aws:policy/ViewOnlyAccess
```

### Stage 3: Multiple Accounts

You need environment isolation. Production shouldn't share an account with dev.

**What you need:**
- AWS Organization to create and manage accounts
- Organizational Units (OUs) for grouping accounts
- Permission sets assigned to specific accounts
- IPAM pools shared across accounts

**Why Organizations?**
- Consolidated billing
- Service Control Policies (SCPs) for guardrails
- Centralized Identity Center management
- Account factory - spin up new accounts in minutes

**Why OUs?**
- Apply policies to groups of accounts
- Share IPAM pools with entire OUs via RAM
- Logical grouping (Workloads/Prod vs Workloads/Dev)

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: acme
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: management-account
    region: us-east-1

  tags:
    organization: acme
    managed-by: crossplane

  # Enable AWS Organizations
  organization:
    awsServiceAccessPrincipals:
      - sso.amazonaws.com

  # Create OU hierarchy
  organizationalUnits:
    - path: Workloads
    - path: Workloads/Prod
    - path: Workloads/Dev

  # Create accounts in OUs
  accounts:
    - name: acme-prod
      email: aws-prod@acme.example.com
      ou: Workloads/Prod

    - name: acme-dev
      email: aws-dev@acme.example.com
      ou: Workloads/Dev

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: Administrators
      - name: Developers

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [Administrators]
        assignToAccounts: [acme-prod, acme-dev]  # Reference by name

      - name: PowerUserAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [Developers]
        assignToAccounts: [acme-dev]  # Developers only get dev access

  ipam:
    scope: private
    homeRegion: us-east-1
    operatingRegions: [us-east-1]

    pools:
      - name: ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        allocationDefaultNetmaskLength: 20

      - name: ipv6-public
        addressFamily: ipv6
        scope: public
        region: us-east-1
        locale: us-east-1
        amazonProvidedIpv6CidrBlock: true
        publicIpSource: amazon
        awsService: ec2
        allocationDefaultNetmaskLength: 56
```

### Stage 4: Enterprise

You have dedicated teams, compliance requirements, and need centralized services.

**What changes:**
- Dedicated accounts for security tooling, shared services, logging
- Delegated administration (Identity Center and IPAM managed from shared-services, not management account)
- Separate IPAM pools per environment with RAM sharing to OUs
- More granular permission sets

**Why delegate administration?**
- Management account should only manage Organizations
- Reduces blast radius if credentials are compromised
- Teams can self-service within their delegated scope

**Why separate IPAM pools?**
- Prod and dev don't compete for IP space
- Different allocation sizes per environment
- Clear boundaries and quotas

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: acme
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: management-account
    region: us-east-1

  tags:
    organization: acme

  organization:
    awsServiceAccessPrincipals:
      - sso.amazonaws.com
      - ipam.amazonaws.com
      - ram.amazonaws.com

  organizationalUnits:
    - path: Security
    - path: Infrastructure
    - path: Workloads
    - path: Workloads/Prod
    - path: Workloads/NonProd

  accounts:
    # Security account - GuardDuty, Security Hub, CloudTrail
    - name: acme-security
      email: aws-security@acme.example.com
      ou: Security

    # Shared services - Identity Center admin, IPAM admin, CI/CD
    - name: acme-shared
      email: aws-shared@acme.example.com
      ou: Infrastructure

    # Workload accounts
    - name: acme-prod
      email: aws-prod@acme.example.com
      ou: Workloads/Prod

    - name: acme-staging
      email: aws-staging@acme.example.com
      ou: Workloads/NonProd

    - name: acme-dev
      email: aws-dev@acme.example.com
      ou: Workloads/NonProd

  # Delegate Identity Center and IPAM to shared-services
  delegatedAdministrators:
    - servicePrincipal: sso.amazonaws.com
      account: acme-shared
    - servicePrincipal: ipam.amazonaws.com
      account: acme-shared

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: PlatformAdmins
        description: Full access to all accounts
      - name: SecurityTeam
        description: Security tooling access
      - name: ProdEngineers
        description: Production deployment access
      - name: Developers
        description: Development environment access

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [PlatformAdmins]
        assignToAccounts: [acme-shared, acme-security, acme-prod, acme-staging, acme-dev]

      - name: SecurityAudit
        managedPolicies:
          - arn:aws:iam::aws:policy/SecurityAudit
        assignToGroups: [SecurityTeam]
        assignToAccounts: [acme-security, acme-prod, acme-staging, acme-dev]

      - name: ProdDeploy
        sessionDuration: PT2H  # Short sessions for prod
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [ProdEngineers]
        assignToAccounts: [acme-prod]

      - name: DevAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [Developers]
        assignToAccounts: [acme-staging, acme-dev]

  ipam:
    delegatedAdminAccount: acme-shared
    homeRegion: us-east-1
    operatingRegions: [us-east-1, us-west-2]

    pools:
      # Production pool - shared with Workloads/Prod OU
      - name: prod-ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.0.0.0/12      # 10.0.0.0 - 10.15.255.255
        allocationDefaultNetmaskLength: 20
        ramShareTargets:
          - ou: Workloads/Prod

      # Non-prod pool - shared with Workloads/NonProd OU
      - name: nonprod-ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.16.0.0/12     # 10.16.0.0 - 10.31.255.255
        allocationDefaultNetmaskLength: 20
        ramShareTargets:
          - ou: Workloads/NonProd

      # Shared services pool
      - name: shared-ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.32.0.0/16     # 10.32.0.0 - 10.32.255.255
        allocationDefaultNetmaskLength: 24
        ramShareTargets:
          - account: acme-shared

      # IPv6 for all workloads
      - name: ipv6-public
        addressFamily: ipv6
        scope: public
        region: us-east-1
        locale: us-east-1
        amazonProvidedIpv6CidrBlock: true
        publicIpSource: amazon
        awsService: ec2
        allocationDefaultNetmaskLength: 56
        ramShareTargets:
          - ou: Workloads
```

## Using Account ProviderConfigs

Foundation creates a ProviderConfig for each account that assumes `OrganizationAccountAccessRole`. Reference accounts by name in downstream resources:

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: VPC
spec:
  providerConfigRef:
    name: acme-prod  # Assumes role into acme-prod account
  forProvider:
    region: us-east-1
    ipv4IpamPoolId: <from-foundation-status>
    ipv4NetmaskLength: 20
```

## Status

Foundation surfaces status from all components:

```yaml
status:
  ready: true
  organization:
    organizationId: o-abc123
    rootId: r-abc1
  organizationalUnits:
    Workloads/Prod: ou-xxx-prod
    Workloads/NonProd: ou-xxx-nonprod
  accounts:
    - name: acme-prod
      id: "111111111111"
      ready: true
    - name: acme-dev
      id: "222222222222"
      ready: true
  identityCenter:
    ready: true
  ipam:
    ready: true
    id: ipam-12345678
    pools:
      - name: prod-ipv4
        id: ipam-pool-abc123
```

## Development

```bash
make render-individual     # Stage 1 example
make render-enterprise     # Stage 4 example
make render-minimal        # Organization only
make test                  # Run tests
make validate              # Validate compositions
make e2e                   # E2E tests
```

## License

Apache-2.0
