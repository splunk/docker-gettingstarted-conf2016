clean:
	-docker kill wordpress wordpress_db splunk my_app splunkforwarder_mysql_logs
	-docker rm -v wordpress wordpress_db splunk my_app splunkforwarder_mysql_logs
	-docker network rm net_wordpress net_splunk net_myapp
	-docker volume rm volume_wordpress_db_data volume_wordpress_db_logs volume_splunk_etc volume_splunk_var

step0:
	docker pull mariadb
	docker pull wordpress
	docker pull haproxy
	docker pull splunk/enterprise:6.4.3-monitor
	docker pull splunk/universalforwarder:6.4.3
	docker pull node:4-onbuild
	(cd traffic_gen && docker build -t my_app .)

step1:
	@echo "\n- Creating new network net_wordpress for Wordpress + DB\n"
	docker network create net_wordpress
	@echo "\n- Creating volume for DB\n"
	docker volume create --name=volume_wordpress_db_data
	@echo "\n- Creating volume for logs\n"
	docker volume create --name=volume_wordpress_db_logs
	@echo "\n- Starting Wordpress DB (MariaDB), also specifying to collect additional logs\n"
	docker run \
		--name wordpress_db \
		--volume volume_wordpress_db_data:/var/lib/mysql \
		--volume volume_wordpress_db_logs:/var/log/mysql \
		--env MYSQL_ROOT_PASSWORD=my-secret-pw \
		--net net_wordpress \
		-d mariadb --slow_query_log --slow_query_log_file=/var/log/mysql/slow_query.log --long_query_time=0.001
	@echo "\n- Starting Wordpress\n"
	docker run \
		--name wordpress \
		--env WORDPRESS_DB_HOST=wordpress_db \
		--env WORDPRESS_DB_PASSWORD=my-secret-pw \
		--net net_wordpress \
		--publish 80:80 \
		-d wordpress
	@echo ""
	@echo "+ - - - - - - - - - - - - - - - +    + - - - - - - - - - - - - - - - - - - - - - - - - - +"
	@echo " net_wordpress                        Volumes"
	@echo "|                               |    |                                                   |"
	@echo "     +----------------------+             +------------------------------------------+"
	@echo "|    |wordpress_db          +---+----+--->| volume_wordpress_db_data:/var/lib/mysql  |   |"
	@echo "     |                      |             +------------------------------------------+"
	@echo "|    |                      |   |    |    +------------------------------------------+   |"
	@echo "     |                      +------------>| volume_wordpress_db_logs:/var/log/mysql  |"
	@echo "|    +----------------------+   |    |    +------------------------------------------+   |"
	@echo "     +----------------------+"
	@echo "|    |wordpress             |   |    + - - - - - - - - - - - - - - - - - - - - - - - - - +"
	@echo "     |                      |"
	@echo "|    |                      |   |"
	@echo "     |                      |"
	@echo "|    +-----------+----------+   |"
	@echo "                 |"
	@echo "|                |              |"
	@echo " - - - - - - - - + - - - - - - -"
	@echo "                 |"
	@echo "                 v"
	@echo "            +----------+"
	@echo "            |    80    |"
	@echo "            +----------+"
	@echo ""

step2:
	@echo "\n- Creating new network net_splunk for Splunk\n"
	docker network create net_splunk
	docker volume create --name=volume_splunk_etc
	docker volume create --name=volume_splunk_var
	docker run --name splunk \
		--hostname splunk \
		--net net_splunk \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_USER=root \
		--env SPLUNK_ENABLE_LISTEN=9997 \
		--env SPLUNK_ADD="index myapp" \
		--env SPLUNK_ADD_1="index mysql_logs" \
		--publish 8000:8000 \
		--publish 8088:8088 \
		--volume /var/lib/docker/containers:/host/containers:ro \
		--volume /var/log:/docker/log:ro \
		--volume /var/run/docker.sock:/var/run/docker.sock:ro \
		--volume volume_splunk_etc:/opt/splunk/etc \
		--volume volume_splunk_var:/opt/splunk/var \
		-d splunk/enterprise:6.4.3-monitor
	@echo ""
	@echo "+ - - - - - - - - - - - - +         + - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	@echo " net_splunk                          Volumes                                                 |"
	@echo "|                         |         |"
	@echo "     +----------------+                +--------------------------------------------------+  |"
	@echo "|    |                |---+---------+->|        volume_splunk_etc:/opt/splunk/etc         |"
	@echo "     |                |                +--------------------------------------------------+  |"
	@echo "|    |                |   |         |  +--------------------------------------------------+"
	@echo "     |                |--------------->|        volume_splunk_var:/opt/splunk/var         |  |"
	@echo "|    |                |   |         |  +--------------------------------------------------+"
	@echo "     |                |                                                                      |"
	@echo "|    |                |   |         + - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	@echo "     |     splunk     |                +--------------------------------------------------+"
	@echo "|    |                |---+----------->|  /var/lib/docker/containers:/host/containers:ro  |"
	@echo "     |                |                +--------------------------------------------------+"
	@echo "|    |                |   |            +--------------------------------------------------+"
	@echo "     |                |--------------->|             /var/log:/docker/log:ro              |"
	@echo "|    |                |   |            +--------------------------------------------------+"
	@echo "     |                |                +--------------------------------------------------+"
	@echo "|    |                |---+----------->|   /var/run/docker.sock:/var/run/docker.sock:ro   |"
	@echo "     +--+---------+---+                +--------------------------------------------------+"
	@echo "|       |         |       |"
	@echo " - - - -|- - - - -|- - - -"
	@echo "        |         |"
	@echo "        v         v"
	@echo "    +------+  +------+"
	@echo "    | 8000 |  | 8088 |"
	@echo "    +------+  +------+"
	@echo ""

step3:
	@echo "\n- Monitoring files in mysql image using Splunk Universal Forwarder.\n"
	docker run --name splunkforwarder_mysql_logs \
		--net net_splunk \
		--volume volume_wordpress_db_logs:/var/log/mysql \
		--env SPLUNK_START_ARGS="--accept-license" \
		--env SPLUNK_FORWARD_SERVER=splunk:9997 \
		--env SPLUNK_ADD="monitor /var/log/mysql/ -index mysql_logs -auth admin:changeme" \
		-d splunk/universalforwarder:6.4.3
	@echo ""
	@echo "+ - - - - - - - - - - - - - - - - -"
	@echo " net_splunk                        |"
	@echo "|"
	@echo "    +--------------------------+   |"
	@echo "|   |                          |"
	@echo "    |          splunk          |   |"
	@echo "|   |                          |"
	@echo "    +--------------------------+   |"
	@echo "|                 ^                    + - - - - - - - - - - - - - - - - - - - - - - -"
	@echo "                  |                |    Volumes                                       |"
	@echo "|                 |                    |"
	@echo "    +--------------------------+   |                                                  |"
	@echo "|   |                          |       |   +---------------------------------------+"
	@echo "    |splunkforwarder_mysql_logs|---+------>|                                       |  |"
	@echo "|   |                          |       |   |                                       |"
	@echo "    +--------------------------+   |       |                                       |  |"
	@echo "|                                      |   |                                       |"
	@echo " - - - - - - - - - - - - - - - - - +       |                                       |  |"
	@echo "                                       |   |                                       |"
	@echo "+ - - - - - - - - - - - - - - - - -        |volume_wordpress_db_logs:/var/log/mysql|  |"
	@echo " net_wordpress                     |   |   |                                       |"
	@echo "|                                          |                                       |  |"
	@echo "   +---------------------------+   |   |   |                                       |"
	@echo "|  |                           |           |                                       |  |"
	@echo "   |       wordpress_db        |---+---+-->|                                       |"
	@echo "|  |                           |           |                                       |  |"
	@echo "   +---------------------------+   |   |   +---------------------------------------+"
	@echo "|                                                                                     |"
	@echo " - - - - - - - - - - - - - - - - - +   + - - - - - - - - - - - - - - - - - - - - - - -"
	@echo ""

step4:
	@echo "\n- Starting our node.js application with splunk-javascript-logging"
	-docker network create net_myapp
	-docker network connect net_myapp splunk
	docker run \
		--name my_app \
		--net net_myapp \
		--env SPLUNK_TOKEN=00000000-0000-0000-0000-000000000000 \
		--env SPLUNK_URL=https://splunk:8088 \
		--env SPLUNK_SOURCETYPE=fake-data \
		--env SPLUNK_SOURCE=nodejs-sdk \
		--env SPLUNK_INDEX=myapp \
		-d my_app
	@echo ""
	@echo "+ - - - - - - - - - - - - - - - - - - - - -  + - - - - - - - - +"
	@echo " net_myapp                                 |  net_splunk"
	@echo "|                                            |                 |"
	@echo "    +--------------------+         +-------+------------+"
	@echo "|   |                    |         |                    |      |"
	@echo "    |                    |         |                    |"
	@echo "|   |       my_app       |--8088-->|       splunk       |      |"
	@echo "    |                    |         |                    |"
	@echo "|   |                    |         |                    |      |"
	@echo "    +--------------------+         +-------+------------+"
	@echo "|                                            |                 |"
	@echo " - - - - - - - - - - - - - - - - - - - - - +  - - - - - - - - -"
	@echo ""

step5:
	@echo "\n- Killing and removing existing Wordpress and DB (we keep the data in volumes)\n"
	docker kill wordpress_db wordpress
	docker rm -v wordpress_db wordpress
	@echo "\n- Restarting DB with logging driver.\n"
	docker run \
		--name wordpress_db \
		--volume volume_wordpress_db_data:/var/lib/mysql \
		--volume volume_wordpress_db_logs:/var/log/mysql \
		--env MYSQL_ROOT_PASSWORD=my-secret-pw \
		--label wordpress=db \
		--net net_wordpress \
			--log-driver=splunk \
				--log-opt splunk-token=00000000-0000-0000-0000-000000000000 \
				--log-opt splunk-url=https://127.0.0.1:8088 \
				--log-opt splunk-insecureskipverify=true \
				--log-opt splunk-index=main \
				--log-opt splunk-sourcetype=httpevent \
				--log-opt splunk-source=db \
				--log-opt labels=wordpress \
				--log-opt tag="{{.Name}}" \
		-d mariadb --slow_query_log --slow_query_log_file=/var/log/mysql/slow_query.log --long_query_time=0.001
	@echo "\n- Restarting Wordpress with logging driver.\n"
	docker run \
		--name wordpress \
		--label wordpress=web \
		--env WORDPRESS_DB_HOST=wordpress_db \
		--env WORDPRESS_DB_PASSWORD=my-secret-pw \
		--net net_wordpress \
			--log-driver=splunk \
				--log-opt splunk-token=00000000-0000-0000-0000-000000000000 \
				--log-opt splunk-url=https://127.0.0.1:8088 \
				--log-opt splunk-insecureskipverify=true \
				--log-opt splunk-index=main \
				--log-opt splunk-sourcetype=httpevent \
				--log-opt splunk-source=web \
				--log-opt labels=wordpress \
				--log-opt tag="{{.Name}}" \
		--publish 80:80 \
		-d wordpress
	@echo ""
	@echo "                                       + - - - - - - - - - - - - +"
	@echo "                                        net_splunk"
	@echo "                                       |                         |"
	@echo "                                            +----------------+"
	@echo "                                       |    |                |   |"
	@echo "                                            |     splunk     |"
	@echo "                                       |    |                |   |"
	@echo "+ - - - - - - - - - - - - - - - +           +-------+--------+"
	@echo " net_wordpress                         |            |            |"
	@echo "|                               |       - - - - - - + - - - - - -"
	@echo "                                                    |"
	@echo "|    +----------------------+   |                   v"
	@echo "     |wordpress_db          |                    +------+"
	@echo "|    |                      |   |                |      |"
	@echo "     |                      |------------------->|      |"
	@echo "|    |                      |   |                |      |"
	@echo "     +----------------------+                    |      |"
	@echo "|    +----------------------+   |                | 8088 |"
	@echo "     |wordpress             |                    |      |"
	@echo "|    |                      |   |                |      |"
	@echo "     |                      |------------------->|      |"
	@echo "|    |                      |   |                |      |"
	@echo "     +----------------------+                    +------+"
	@echo "|                               |"
	@echo " - - - - - - - - - - - - - - - -"
	@echo ""
