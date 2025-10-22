@description('Resource name suffix.')
param suffix string

@description('Name of Application Gateway resource.')
param appGatewayName string = 'agw-${suffix}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('ID of the public subnet for Application Gateway.')
param publicSubnetId string

@description('FQDN of backend application.')
param backendFqdn string

@secure()
@description('Key Vault certificate secret ID for HTTPS listener.')
param keyVaultCertSecretId string

// Suppression du paramètre wafPolicyId car il n'est plus utilisé

resource appGateway 'Microsoft.Network/applicationGateways@2022-09-01' = {
  name: appGatewayName
  location: location
  sku: {
    name: 'Standard_v2'
    tier: 'Standard_v2'
    capacity: 2
  }
  properties: {
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
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'httpsPort')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'appGatewaySslCert')
          }
          requireServerNameIndication: true
          hostNames: [backendFqdn]
          customErrorConfigurations: []
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'aciBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: backendFqdn
            }
          ]
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
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'aciHealthProbe')
          }
          probeEnabled: true
          connectionDraining: {
            enabled: false
            drainTimeoutInSec: 30
          }
          trustedRootCertificates: []
          path: '/'
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpsListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'aciBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'aciBackendHttpSettings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      fileUploadLimitInMb: 100
      maxRequestBodySizeInKb: 128
      exclusions: []
    }
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
  }
}

output appGatewayId string = appGateway.id
