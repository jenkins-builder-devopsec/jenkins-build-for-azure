import groovy.json.JsonSlurper

def getFtpPublishProfile(def publishProfilesJson) {
  def pubProfiles = new JsonSlurper().parseText(publishProfilesJson)
  for (p in pubProfiles)
    if (p['publishMethod'] == 'FTP')
      return [url: p.publishUrl, username: p.userName, password: p.userPWD]
}

node {
  def secrets = [
        [secretType: 'Secret', name: 'webapps-res-grp', envVariable: 'resourceGroup' ],        
        [secretType: 'Secret', name: 'java-t3-webapp-name', envVariable: 'webAppName' ],
      ]

  withAzureKeyvault(secrets) {
    sh "echo WEBAPPRESGRP: $resourceGroup"
    sh "echo WEBAPPNAME: $webAppName"

    stage('init-scm') {
      checkout scm
    }
  
    stage('build') {
      def mvn_version = 'maven'
      withEnv( ["PATH+MAVEN=${tool mvn_version}/bin"] ) {
        sh "mvn clean package"
      }
    }
  
    stage('deploy') {
      //def resourceGroup = 'webappsAzRes'
      //def webAppName = 'java-t3-webapp'
       // login Azure
      withCredentials([azureServicePrincipal('service_principal')]) {            
        sh 'az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET -t $AZURE_TENANT_ID'
        sh 'az account set -s $AZURE_SUBSCRIPTION_ID'        
      }
      // get publish settings
      def pubProfilesJson = sh script: "az webapp deployment list-publishing-profiles -g $resourceGroup -n $webAppName", returnStdout: true
      def ftpProfile = getFtpPublishProfile pubProfilesJson
      // upload package
      sh "curl -T target/calculator-1.0.war $ftpProfile.url/webapps/ROOT.war -u '$ftpProfile.username:$ftpProfile.password'"
      // log out
      sh 'az logout'
    }
  }
}
