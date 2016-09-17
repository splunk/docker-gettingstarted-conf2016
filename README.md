# docker-gettingstarted-dockercon16

Splunk Enterprise Docker Image
Demo of Splunk Image with Docker App running in Docker container (Note this image is not yet available on public repo due to legal issues— we are working to resolve and plan to make it publicly available in the future. Additionally we plan to make the docker app available on Splunkbase)
1) You will need a DockerHub account
2) You will need a GitHub Account
3) Please send account info to marc chene for access to both repos
4) You will need an IDE on your system so you can run make and git commands
 
## Steps for configuring demo
1. Install Docker Toolbox (Mac OS below)
 * https://docs.docker.com/mac/step_one/

2. Open Docker QuickStart Terminal
 * login to dockerhub account (command: docker login) - you will then be prompted to enter your credentials

3. Clone Github Repo
 * In Terminal enter command: 
git clone https://github.com/splunk/docker-gettingstarted-dockercon16.git
  * you will be prompted to login to github - you will be prompted to enter credentials
  * Access the github directory that was just created
 * Enter the following commands and let each run
   * make clean [Note: you will get Error 1 (ignored) if running first time]
   * make step0
   * make step1
   * make step2
   * make step3
   * make step4

4. Access your Splunk Enterprise web UI, http://127.0.0.1:8000/

5. Try a sample field extraction for the sample app
 * Give yourself read access to the new Splunk indexes
   * Go to Settings > Access Controls > Roles > Admin
   * Indexes searched by default
   * Add docker and mysql_logs
   * SAVE

 * Go to the search app
  * search sourcetype=“fake-data"
  * Select Extract new fields
   * select event click next
   * select method regular expression
   ** extract (email portion) label as “Email"
    * extract (ip address as) “IP_Address"
    * extract ID portion as “ID"

5. Demonstrate how you can use the Splunk logging driver, https://docs.docker.com/engine/admin/logging/splunk/
 * Go back to your terminal window and enter command: 
  * make step5 

 * Look at the Splunk logging driver data from the Splunk docker overview dashboard, http://127.0.0.1:8000/en-US/app/app-docker/docker_overview?form.time.earliest=rt-10m&form.time.latest=rt&form.container_name=*&earliest=0&latest=

Showing the Docker Overview screen provides good insight into a breadth of items you can show.

# Get help and support

More information about the Docker images and how to pull and run them is available in the README for each image.

If you have questions or need support, you can:
* Post a question to [Splunk Answers](http://answers.splunk.com)
* Join the [Splunk Slack channel](http://splunk-usergroups.slack.com)
* Visit the #splunk channel on [EFNet Internet Relay Chat](http://www.efnet.org)
* Send an email to [docker-maint@splunk.com](mailto:docker-maint@splunk.com)
