#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - unzip
  - jq
  - git
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - software-properties-common
  - expect

runcmd:
  # --- Create githubrunner user ---
  - useradd -m -s /bin/bash githubrunner
  - echo "githubrunner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/githubrunner
  
  # --- Install Docker ---
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io

  # Add user to docker group
  - usermod -aG docker azureuser
  - usermod -aG docker githubrunner

  # --- Enable Docker on startup ---
  - systemctl enable docker
  - systemctl start docker

  # --- Install Terraform ---
  - curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
  - apt update && apt install -y terraform

  # --- Install Azure CLI ---
  - curl -sL https://aka.ms/InstallAzureCLIDeb | bash

  # --- Set up GitHub Actions Runner ---
  - mkdir -p /home/githubrunner/actions-runner
  - cd /home/githubrunner/actions-runner
  - curl -o actions-runner-linux-x64-2.326.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.326.0/actions-runner-linux-x64-2.326.0.tar.gz
  - echo "9c74af9b4352bbc99aecc7353b47bcdfcd1b2a0f6d15af54a99f54a0c14a1de8  actions-runner-linux-x64-2.326.0.tar.gz" | shasum -a 256 -c
  - tar xzf ./actions-runner-linux-x64-2.326.0.tar.gz
  - chown -R githubrunner:githubrunner /home/githubrunner/actions-runner

  # --- Configure the runner (Token will need to be injected securely using Terraform) ---
  - |
    su - githubrunner -c "cd ~/actions-runner && \
      expect -c '
      spawn ./config.sh --url https://github.com/VictortheGreat7/Cloud_Engineering_Assessment --token ${github_runner_token}
      expect {
          \"Enter the name of the runner group to add this runner to:\" { send \"\r\"; exp_continue }
          \"Enter the name of runner:\" { send \"\r\"; exp_continue }
          \"Enter any additional labels (ex. label-1,label-2):\" { send \"\r\"; exp_continue }
          \"Enter name of work folder:\" { send \"\r\"; exp_continue }
          timeout { puts \"Timeout: Unexpected prompt encountered\"; exit 1 }
      }
      expect eof
      '"

  - curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  - sudo apt install -y nodejs
  - node -v
  - npm -v

  # --- Create a systemd service to keep the runner running ---
  - |
    cat << 'EOF' > /etc/systemd/system/github-runner.service
    [Unit]
    Description=GitHub Actions Runner
    After=network.target

    [Service]
    ExecStart=/home/githubrunner/actions-runner/run.sh
    WorkingDirectory=/home/githubrunner/actions-runner
    Restart=always
    User=githubrunner

    [Install]
    WantedBy=multi-user.target
    EOF

  - systemctl daemon-reexec
  - systemctl daemon-reload
  - systemctl enable github-runner
  - systemctl start github-runner

final_message: "🎉 GitHub Runner VM setup complete!"
