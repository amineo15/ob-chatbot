@description('Resource name suffix.')
param suffix string

@description('Name of Application Gateway resource.')
param appGatewayName string = 'agw-${suffix}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('ID of the public subnet for Application Gateway.')
param publicSubnetId string

@description('ID of the private subnet for backend (ACI).')
param privateSubnetId string

@description('FQDN of backend application.')
param backendFqdn string

@description('Key Vault certificate secret ID for HTTPS listener.')
param keyVaultCertSecretId string

@description('WAF policy resource ID.')
param wafPolicyId string

resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: appGatewayName
  location: location
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
    capacity: 2
  }
  properties: {
    zones: ['1','2','3']
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: publicSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: null
          subnet: {
            id: publicSubnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'httpsPort'
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: 'appGatewaySslCert'
        properties: {
          keyVaultSecretId: keyVaultCertSecretId
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: appGateway.frontendIPConfigurations[0].id
          }
          frontendPort: {
            id: appGateway.frontendPorts[0].id
          }
          protocol: 'Https'
          sslCertificate: {
            id: appGateway.sslCertificates[0].id
          }
          requireServerNameIndication: true
          hostNames: [backendFqdn]
          customErrorConfigurations: []
          sslProfile: {
            name: 'latestTlsProfile'
            properties: {
              policyName: 'AppGwSslPolicy202201'
              policyType: 'Predefined'
              minProtocolVersion: 'TLSv1_2'
              cipherSuites: []
            }
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'aciBackendPool'
        properties: {
          fqdns: [backendFqdn]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'aciBackendHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          hostName: backendFqdn
          probe: {
            id: appGateway.probes[0].id
          }
          pickHostNameFromBackendAddress: true
          probeEnabled: true
          affinity: 'None'
          connectionDraining: {
            enabled: false
            drainTimeoutInSec: 30
          }
          trustedRootCertificates: []
          path: '/'
          enableHttp2: true
        }
      }
    ]
    probes: [
      {
        name: 'aciHealthProbe'
        properties: {
          protocol: 'Http'
          host: backendFqdn
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          match: {
            statusCodes: ['200']
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpsRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: appGateway.httpListeners[0].id
          }
          backendAddressPool: {
            id: appGateway.backendAddressPools[0].id
          }
          backendHttpSettings: {
            id: appGateway.backendHttpSettingsCollection[0].id
          }
        }
      }
    ]
    wafConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      fileUploadLimitInMb: 100
      maxRequestBodySizeInKb: 128
      exclusions: []
      policy: {
        id: wafPolicyId
      }
    }
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
    diagnosticSettings: [
      {
        name: 'appGatewayDiagnostics'
        properties: {
          logs: [
            {
              category: 'ApplicationGatewayAccessLog'
              enabled: true
            }
            {
              category: 'ApplicationGatewayPerformanceLog'
              enabled: true
            }
            {
              category: 'ApplicationGatewayFirewallLog'
              enabled: true
            }
          ]
          metrics: [
            {
              category: 'AllMetrics'
              enabled: true
            }
          ]
          workspaceId: '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.OperationalInsights/workspaces/<log-analytics-workspace>'
        }
      }
    ]
  }
}

output appGatewayId string = appGateway.id
