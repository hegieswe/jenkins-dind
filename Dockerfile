FROM jenkins/jenkins:lts

USER root

# Menginstall dependensi dasar
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release python3

# Menginstall Docker CLI & Docker Buildx
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin

# Menginstall Kubectl (untuk tahap CD)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Membersihkan cache apt
RUN rm -rf /var/lib/apt/lists/*

# Copy script CI/CD global ke dalam bin jenkins
COPY ci.sh /usr/local/bin/ci.sh
COPY cd.sh /usr/local/bin/cd.sh
RUN chmod +x /usr/local/bin/ci.sh /usr/local/bin/cd.sh
