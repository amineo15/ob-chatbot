@description('Resource name suffix.')
param suffix string

@description('Name of Managed Identity resource.')
param name string = 'id-${suffix}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Owner of the managed identity.')
param owner string

@description('Environment (ex: dev, prod).')
param environment string

@description('Usage description for the managed identity.')
param usage string = 'Resource identity for Azure services only. No B2E users.'

@description('Date of next access review (ISO format).')
param reviewDate string

// ENGIE Compliance: Managed Identity must be created in the resource tenant, reserved for resource usage only (no B2E users).
// Tags added for traceability, ownership, environment, and review.

//----------- Managed Identity Resource -----------//
resource managed_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: {
    Owner: owner
    Environment: environment
    Usage: usage
    ReviewDate: reviewDate
    Compliance: 'ENGIE'
  }
}

//----------- Outputs -----------//
output name string = managed_identity.name
output principalId string = managed_identity.properties.principalId
output clientId string = managed_identity.properties.clientId
