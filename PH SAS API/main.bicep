// Region for all resources
param location string = resourceGroup().location

@secure()
param aadUsername string
@secure()
param aadSid string

// Variables
var hostingPlanName = 'asp-jrghkmid-prd-001'
var webSiteName = 'azapp-SASapi-prd-001'


// Web App resources
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: hostingPlanName
}

resource webSite 'Microsoft.Web/sites@2022-03-01' = {
  name: webSiteName
  location: location
  properties: {
    serverFarmId: hostingPlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output principalId string = webSiteName
output webSiteHostName string = webSite.properties.defaultHostName
