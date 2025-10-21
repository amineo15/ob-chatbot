@description('Resource name suffix.')
param suffix string

@description('Name of Virtual Network resource.')
param vnetName string = 'vnet-${suffix}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of public subnet.')
param publicSubnetName string = 'public-subnet-${suffix}'

@description('Name of private subnet.')
param privateSubnetName string = 'private-subnet-${suffix}'

@description('Name of NSG for public subnet.')
param publicNsgName string = 'nsg-public-${suffix}'

@description('Name of NSG for private subnet.')
param privateNsgName string = 'nsg-private-${suffix}'

@description('Address prefix for VNet.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Address prefix for public subnet.')
param publicSubnetPrefix string = '10.10.1.0/24'

@description('Address prefix for private subnet.')
param privateSubnetPrefix string = '10.10.2.0/24'

// Storage Account for Flow Logs
@description('Central Storage Account for Flow Logs.')
param flowLogStorageAccountName string

// DDoS Protection Plan
@description('Resource ID of DDoS Protection Plan.')
param ddosPlanId string

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: publicSubnetName
        properties: {
          addressPrefix: publicSubnetPrefix
          networkSecurityGroup: {
            id: publicNsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetPrefix
          networkSecurityGroup: {
            id: privateNsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          delegations: []
        }
      }
    ]
    enableDdosProtection: true
    ddosProtectionPlan: {
      id: ddosPlanId
    }
  }
}

resource publicNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: publicNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-deny-inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource privateNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: privateNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-deny-inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-09-01' = {
  name: 'NetworkWatcher_${location}'
  location: location
}

resource flowLogsPublic 'Microsoft.Network/networkWatchers/flowLogs@2023-09-01' = {
  name: '${networkWatcher.name}/flowLogs-${publicNsgName}'
  location: location
  properties: {
    targetResourceId: publicNsg.id
    storageId: resourceId('Microsoft.Storage/storageAccounts', flowLogStorageAccountName)
    enabled: true
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      days: 365
      enabled: true
    }
  }
}

resource flowLogsPrivate 'Microsoft.Network/networkWatchers/flowLogs@2023-09-01' = {
  name: '${networkWatcher.name}/flowLogs-${privateNsgName}'
  location: location
  properties: {
    targetResourceId: privateNsg.id
    storageId: resourceId('Microsoft.Storage/storageAccounts', flowLogStorageAccountName)
    enabled: true
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      days: 365
      enabled: true
    }
  }
}

output vnetId string = vnet.id
output publicSubnetId string = vnet.properties.subnets[0].id
output privateSubnetId string = vnet.properties.subnets[1].id
output publicNsgId string = publicNsg.id
output privateNsgId string = privateNsg.id
