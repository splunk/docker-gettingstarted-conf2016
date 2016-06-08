clean:
	-docker kill wordpress wordpress_db splunk
	-docker rm -v wordpress wordpress_db splunk
	-docker network rm net_wordpress net_splunk
	-docker volume rm volume_wordpress_db_data volume_wordpress_db_logs volume_splunk_etc volume_splunk_var

step0:
	docker pull mariadb
	docker pull wordpress
	docker pull haproxy
	docker pull splunk/enterprise:6.4.1-monitor
	docker pull splunk/universalforwarder:6.4.1

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
		--env SPLUNK_ADD="index docker" \
		--env SPLUNK_ADD_1="index mysql_logs" \
		--env SPLUNK_CMD="http-event-collector create -uri https://localhost:8089 -auth admin:changeme -name docker -index docker" \
		--publish 8000:8000 \
		--publish 8088:8088 \
		--volume /var/lib/docker/containers:/host/containers:ro \
		--volume /var/log:/docker/log:ro \
		--volume /var/run/docker.sock:/var/run/docker.sock:ro \
		-d splunk/enterprise:6.4.1-monitor

step3:
	@echo "\n- Monitoring files in mysql image using Splunk Universal Forwarder.\n"
	docker run --name splunkforwarder_mysql_logs \
		--net net_splunk \
		--volume volume_wordpress_db_logs:/var/log/mysql \
		--env SPLUNK_FORWARD_SERVER=splunk:9997 \
		--env SPLUNK_ADD="monitor /var/log/mysql/ -index mysql_logs -auth admin:changeme" \
		-d splunk/universalforwarder:6.4.1

step4:
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
				--log-opt splunk-token=$$(docker exec splunk entrypoint.sh splunk http-event-collector list -uri https://localhost:8089 -auth admin:changeme | grep token | head -1 | cut -d'=' -f2) \
				--log-opt splunk-url=https://localhost:8088 \
				--log-opt splunk-insecureskipverify=true \
				--log-opt splunk-index=docker \
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
				--log-opt splunk-token=$$(docker exec splunk entrypoint.sh splunk http-event-collector list -uri https://localhost:8089 -auth admin:changeme | grep token | head -1 | cut -d'=' -f2) \
				--log-opt splunk-url=https://localhost:8088 \
				--log-opt splunk-insecureskipverify=true \
				--log-opt splunk-index=docker \
				--log-opt splunk-sourcetype=httpevent \
				--log-opt splunk-source=web \
				--log-opt labels=wordpress \
				--log-opt tag="{{.Name}}" \
		--publish 80:80 \
		-d wordpress

