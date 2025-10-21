@description('Name of Managed Identity resource.')
param managed_identity_name string

@description('Name of Storage Account resource.')
param storage_account_name string

@description('Name of AI Foundry resource.')
param ai_foundry_name string

@description('Name of Search Service resource.')
param search_service_name string

@description('Responsible for access review.')
param accessReviewOwner string

@description('Date of next access review (ISO format).')
param accessReviewDate string

//----------- Managed Identity Resource -----------//
resource managed_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managed_identity_name
}

//----------- SCOPE: Storage Account Role Assignments -----------//
resource storage_account 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storage_account_name
}

// PRINCIPAL: Managed Identity
// Usage: Data access only. No admin rights. Reviewed by accessReviewOwner on accessReviewDate.
resource mi_storage_blob_data_contributor_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage_account.id, managed_identity.id, storage_blob_data_contributor_role.id)
  scope: storage_account
  properties: {
    principalId: managed_identity.properties.principalId
    roleDefinitionId: storage_blob_data_contributor_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Data contributor only. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

// PRINCIPAL: Search service
// Usage: Data read only. Reviewed by accessReviewOwner on accessReviewDate.
resource search_storage_blob_data_reader_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage_account.id, search_service.id, storage_blob_data_reader_role.id)
  scope: storage_account
  properties: {
    principalId: search_service.identity.principalId
    roleDefinitionId: storage_blob_data_reader_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Data reader only. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

//----------- SCOPE: Search Service Role Assignments -----------//
resource search_service 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: search_service_name
}

// PRINCIPAL: Managed Identity
// Usage: Index data contributor. Reviewed by accessReviewOwner on accessReviewDate.
resource mi_search_index_data_contributor_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search_service.id, managed_identity.id, search_index_data_contributor_role.id)
  scope: search_service
  properties: {
    principalId: managed_identity.properties.principalId
    roleDefinitionId: search_index_data_contributor_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Index data contributor. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

// PRINCIPAL: Managed Identity
// Usage: Service contributor. Reviewed by accessReviewOwner on accessReviewDate.
resource mi_search_service_contributor_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search_service.id, managed_identity.id, search_service_contributor_role.id)
  scope: search_service
  properties: {
    principalId: managed_identity.properties.principalId
    roleDefinitionId: search_service_contributor_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Service contributor. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

// PRINCIPAL: AI Foundry (OpenAI)
// Usage: Index data contributor. Reviewed by accessReviewOwner on accessReviewDate.
resource foundry_search_index_data_contributor_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search_service.id, ai_foundry.id, search_index_data_contributor_role.id)
  scope: search_service
  properties: {
    principalId: ai_foundry.identity.principalId
    roleDefinitionId: search_index_data_contributor_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Index data contributor. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

//----------- SCOPE: AI Foundry Role Assignments -----------//
resource ai_foundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: ai_foundry_name
}

// PRINCIPAL: Managed Identity
// Usage: OpenAI contributor. Reviewed by accessReviewOwner on accessReviewDate.
resource mi_cognitive_services_openai_contributor_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ai_foundry.id, managed_identity.id, cognitive_services_openai_contributor_role.id)
  scope: ai_foundry
  properties: {
    principalId: managed_identity.properties.principalId
    roleDefinitionId: cognitive_services_openai_contributor_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: OpenAI contributor. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

// PRINCIPAL: Managed Identity
// Usage: Language owner. Reviewed by accessReviewOwner on accessReviewDate.
resource mi_cognitive_services_language_owner_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ai_foundry.id, managed_identity.id, cognitive_services_language_owner_role.id)
  scope: ai_foundry
  properties: {
    principalId: managed_identity.properties.principalId
    roleDefinitionId: cognitive_services_language_owner_role.id
    principalType: 'ServicePrincipal'
    description: 'ENGIE: Language owner. Owner: ${accessReviewOwner}. Next review: ${accessReviewDate}.'
  }
}

// PRINCIPAL: AI Foundry (OpenAI)
// Usage: Language owner. Reviewed by accessReviewOwner on accessReviewDate.
resource foundry_cognitive_services_language_owner_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ai_foundry.id, ai_foundry.id, cognitive
