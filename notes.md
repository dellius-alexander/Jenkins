# Jenkins House Cleaning Considerations

The [Jenkins documentation](https://www.jenkins.io/doc/) provides a rich library of configuration options and is a great reference guide post-installation.  A few considerations are listed below for the best startup experience.

---

## <a href="https://www.jenkins.io/doc/book/pipeline/development/#pipeline-development-tools">Pipeline Development Tools</a>

vscode extension: Jenkins Pipeline Linter Connector 
- Author: by Jan Joerke
- Url: https://marketplace.visualstudio.com/items?itemName=janjoerke.jenkins-pipeline-linter-connector

The extension adds four settings entries to VS Code which you
have to use to configure the Jenkins Server you want to use for
validation.
- jenkins.pipeline.linter.connector.url is the endpoint at which 
  your Jenkins Server expects the POST request, containing your 
  Jenkinsfile which you want to validate. Typically this points 
  to http://<your_jenkins_server:port>/pipeline-model-converter/validate.
- jenkins.pipeline.linter.connector.user allows you to specify 
  your Jenkins username.
- jenkins.pipeline.linter.connector.pass allows you to specify 
  your Jenkins password.
- jenkins.pipeline.linter.connector.crumbUrl has to be specified 
  if your Jenkins Server has CRSF protection enabled. Typically 
  this points to http://<your_jenkins_server:port>/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb). ​

---

## <a href="https://www.jenkins.io/doc/book/pipeline/syntax/#agent-parameters">Pipeline Labels:</a>

Execute the Pipeline, or stage, on an agent available in the Jenkins environment with the provided label. For example: 

```groovy
agent { 
    label 'my-defined-label' 
}
```

The pipeline `label` refers to the `node name` used to run the jenkins builds. This can be found in cloud services.
Go to:
- [] Manage Jenkins ] ---> [ Manage Nodes... ]. You can chose one of these nodes as your agent. Take the string from the column "name". If the name of one of your nodes is for example "master" you can write:

```
pipeline {
    agent {
        label 'master' || 'worker1'
    }
    ...
}
```

*`Note: this was a useful piece of information needed when connecting additional nodes to Jenkins and defining agents during build stages`*

---

## <a href="https://docs.github.com/en/developers/webhooks-and-events/creating-webhooks" id="github-webhook">[Github Webhook](https://docs.github.com/en/developers/webhooks-and-events/creating-webhooks "https://docs.github.com/en/developers/webhooks-and-events/creating-webhooks")</a>

In order to `setup Jenkins to build automatically` you will have to setup a webhook on your repository to trigger a build every time a new commit is made. 

To use Github webhooks in Jenkins, you must install the [Github plugin](https://plugins.jenkins.io/github/) from the `Manage Plugins` console.

Webhooks require a few configuration options before you can make use of them:

  - Payload URL: The payload URL is the URL of the server that will receive the webhook POST requests.
  - Content type: Webhooks can be delivered using different content types:

      - The application/json content type will deliver the JSON payload directly as the body of the POST request.
      - The application/x-www-form-urlencoded content type will send the JSON payload as a form parameter called payload.
  - [Secret](https://docs.github.com/en/developers/webhooks-and-events/securing-your-webhooks): Setting a webhook secret allows you to ensure that POST requests sent to the payload URL are from GitHub.
  - SSL verificatio: If your "Payload URL" is a secure site (HTTPS), you will have the option to configure the SSL verification settings. If your "Payload URL" is not secure (HTTP), GitHub will not display this option. 
  - Active: By default, webhook deliveries are "Active." You can choose to disable the delivery of webhook payloads by deselecting "Active."
  - Events: Events are at the core of webhooks. These webhooks fire whenever a certain action is taken on the repository, which your server's payload URL intercepts and acts upon.
  - Wildcard event: To configure a webhook for all events, use the wildcard (*) character to specify the webhook events.
<br/>

You can install webhooks on an organization or on a specific repository. To set up a webhook, go to the settings page of your repository or organization. From there, click:

  1. `[Webhooks] --> [Add webhook]`

  2.  Fill out the form as follows:
  
      ```yaml
      Payload URL: https://<your/server/url>/github-webhook/
      Content type: application/json
      Secret: [leave blank]
      SSL verification: [select Enable SSL verification]
      Which events would you like to trigger this webhook: [Let me select individual events.]
      # select the below options and select [Add webhook]
      - Pull requests
      - Pushes
      ```

  - Alternatively, you can choose to build and manage a webhook through the [Webhooks API](https://docs.github.com/en/rest/reference/repos#hooks).

That's it, now Github will be able to send POST events to your server. For help setting up your server see [Configuring your server to receive payloads](https://docs.github.com/en/developers/webhooks-and-events/configuring-your-server-to-receive-payloads) for more details.  

---

## <h2><a href="https://www.jenkins.io/doc/book/managing/change-system-timezone/" id="timezone-change">Update Jenkins Timezone</a></h2>

The easy way to update the Jenkins time server is from the `Jenkins Script Console`, go to:

- [Manage Jenkins] --> [Script Console]

This method works on a live system without the need for a restart. This can also be included in a Post-initialization script to make it permanent.
```groovy
System.setProperty('org.apache.commons.jelly.tags.fmt.timeZone', 'America/New_York')
```

---

## <h2><a href="https://www.guru99.com/create-users-manage-permissions.html#2">User Role Permissions:</a> Securing Jenkins</h2>
<br/>


```
In the default configuration of Jenkins 1.x, Jenkins does not perform any security checks. This means the ability of Jenkins to launch processes and access local files are available to anyone who can access Jenkins web UI and some more.
```
You should lock down access to Jenkins UI so that users are authenticated and the appropriate set of permissions are given to them. This setting is controlled mainly by two axes:

- Security Realm, which determines users and their passwords, as well as what groups the users belong to.

- Authorization Strategy, which determines who has access to what.

Jenkins provides several options for securing your Jenkins node.



- [Quick and Simple Security](https://wiki.jenkins.io/display/JENKINS/Quick+and+Simple+Security) --- if you are running Jenkins like java -jar jenkins.war and only need a very simple setup

- [Standard Security Setup](https://wiki.jenkins.io/display/JENKINS/Standard+Security+Setup) --- discusses the most common setup of letting Jenkins run its own user database and do finer-grained access control

- [Apache frontend for security](https://wiki.jenkins.io/display/JENKINS/Apache+frontend+for+security) --- run Jenkins behind Apache and perform access control in Apache instead of Jenkins

- [Authenticating scripted clients](https://wiki.jenkins.io/display/JENKINS/Authenticating+scripted+clients) --- if you need to programmatically access security-enabled Jenkins web UI, use BASIC auth

- [Matrix-based security|Matrix-based security](https://wiki.jenkins.io/display/JENKINS/Matrix-based+security) --- Granting and denying finer-grained permissions

The `Matrix Authorization Strategy` plugin is the best and most versitile strategy to implement user access permissions. It allows you to grant granular permissions to users and groups.

The [Matrix Authorization Strategy](https://plugins.jenkins.io/matrix-auth/) allows configuring the lowest level permissions, such as starting new builds, configuring items, or deleting them, individually. This plugin also allows you to configure `Project-based Matrix Authoriztion Strategy` which is used in this Jenkins deployment. This plugin provides:

- Inherit permissions: This is the default behavior. Permissions explicitly granted on individual items or agents will only add to permissions defined globally or in any parent items.
- Inherit global configuration only: This will only inherit permissions granted globally, but not those granted on parent folders. This way, jobs in folders can control access independently from their parent folder.
- Do not inherit permissions: The most restrictive inheritance configuration. Only permissions defined explicitly on this agent or item will be granted. The only exception is Overall/Administer: It is not possible to remove access to an agent or item from Jenkins administrators.

The plugin can be downloaded from the `Manage Plugins` console:

- [Manage Jenkins] --> [Manage Plugins] --> (select plugins)
    - [Matrix Authorization Strategy](https://plugins.jenkins.io/matrix-auth/)

### Setting up `Matrix-based Security`:

1. Goto `[Manage Jenkins] --> [Configure Global Security] --> [Authorization]`, select:

    - `Project-based Matrix Authoriztion Strategy`: this strategy offers matrix based security at the project level and offers granular access permissions.
    - Configute this setting according to your needs.
      

---

## <a href="https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token" id="github-access-token">Github Access Token</a>

*`Personal access tokens` (PATs) are an alternative to using passwords for authentication to GitHub when using the `GitHub API` or the `command line`.*

In order for Jenkins to access Github repositories you would have to create authentication credentials within Jenkins Credentials Manager. To avoid providing your username and password to Jenkins. We can create a `Personal access token` on `Github` and delete the token to revoke access to `Github` when necessary. A `Personal access token` provides a granular approach to Github resources.

To create an access token, login to [Github.com](https://github.com) and goto:

- `Main Settings` --> `Developer Settings` --> `Personal access tokens` --> `Generate new token`

Add a note for your token and select:

- repo - Full control of private repositories 
- user <br/>|__ read:user - Read ALL user profile data <br/>|__ user:email - Access user email addresses (read-only) 
- *Optional: workflow - Update GitHub Action workflows*
 
***Note: Copy your `Auth Token` in a safe place for later use in `Jenkins`.  Use the token to create a `Username & Password` credentials in Jenkins credentials manager and give it a discriptive name such as, `"github-access-token"`.***

Now you will use these credentials to access Github during build job runtime.