// Region for all resources
param location string = resourceGroup().location

@secure()
param aadUsername string
@secure()
param aadSid string

// Variables
var hostingPlanName = 'asp-phdhkapp-uat-001'
var webSiteName = ''

var sqlserverName = 'sqlsvr-phdhkapp-uat-001'

var appGatewaySubnetName = 'snet-vnet-'

// Web App resources
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  
  sku: {
    name: 'P1v3'
    capacity: 1
  }
  kind: 'Windows'
  properties: {
    reserved: true
  }
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

// Data resources
resource sqlserver 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: sqlserverName
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: aadUsername
      principalType: 'User'
      sid: aadSid
      tenantId: tenant().tenantId
    }
    publicNetworkAccess: 'Enabled'
    version: '12.0'
  }
}

//Allow all azure services: do NOT do this in production! This opens up your database to ALL azure customers azure services! 
//In the demo walkthrough you will lock this down.
resource sqlserverName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlserver
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

//networking resources
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'IntegrationSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'PLSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: name
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/${appGatewaySubnetName}'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'myBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: webSite.properties.defaultHostName
            }

          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          hostName: webSite.properties.defaultHostName
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, 'port_80')
          }
          protocol: 'Http'
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'myListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'myBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'myHTTPSettings')
          }
        }

      }
    ]
  }
}


output principalId string = webSiteName
output sqlserverName string = sqlserverName
output databaseName string = databaseName
output sqlServerFullyQualifiedDomainName string = sqlserver.properties.fullyQualifiedDomainName
output webSiteHostName string = webSite.properties.defaultHostName
