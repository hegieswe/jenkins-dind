.PHONY: up down logs password

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f jenkins

password:
	docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
