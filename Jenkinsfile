pipeline {
    agent any
    environment {
        PROJECT_ID = "project-10094705-9153-43d5-bb8"
        REGISTRY = "asia-south1-docker.pkg.dev/project-10094705-9153-43d5-bb8/my-app-repo/go-app"
        CLUSTER = "my-go-cluster"
        ZONE = "asia-south1-a"
        NAMESPACE = "go-app"
        PATH = "/tmp/google-cloud-sdk/bin:/usr/local/bin:/tmp:/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    }
    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Choose apply or destroy')
    }
    stages {
        stage('Setup Tools') {
            steps {
                sh '''
                  set -e
                  echo "=== Installing dependencies ==="
                  # Install python3 for gcloud installer
                  if ! command -v python3 >/dev/null 2>&1; then
                    apt-get update -qq || true
                    apt-get install -y python3 python3-distutils curl wget unzip sudo 2>/dev/null || true
                    # Try apk if alpine
                    apk add --no-cache python3 curl wget unzip 2>/dev/null || true
                    ln -sf $(which python3) /usr/bin/python 2>/dev/null || ln -sf /usr/bin/python3 /usr/bin/python || true
                  fi
                  if ! command -v python >/dev/null 2>&1; then
                    ln -sf $(which python3) /usr/local/bin/python || ln -sf $(which python3) /usr/bin/python || true
                  fi
                  python3 --version
                  python --version || true

                  echo "=== Installing gcloud ==="
                  if [ ! -f /tmp/google-cloud-sdk/bin/gcloud ]; then
                    curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/tmp --usage-reporting=false
                  fi
                  /tmp/google-cloud-sdk/bin/gcloud --version

                  echo "=== Installing terraform ==="
                  if ! command -v terraform >/dev/null 2>&1 && [ ! -f /usr/local/bin/terraform ]; then
                    wget -q https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -O /tmp/tf.zip
                    unzip -o /tmp/tf.zip -d /tmp/
                    chmod +x /tmp/terraform
                    mv /tmp/terraform /usr/local/bin/terraform || sudo mv /tmp/terraform /usr/local/bin/terraform || cp /tmp/terraform /tmp/terraform-bin
                    chmod +x /usr/local/bin/terraform 2>/dev/null || chmod +x /tmp/terraform-bin
                  fi
                  terraform version || /usr/local/bin/terraform version || /tmp/terraform-bin version

                  echo "=== Installing kubectl ==="
                  /tmp/google-cloud-sdk/bin/gcloud components install kubectl --quiet || true
                  kubectl version --client || /tmp/google-cloud-sdk/bin/kubectl version --client
                '''
            }
        }
        stage('Terraform Apply Infra') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:/usr/local/bin:$PATH
                  gcloud config set project $PROJECT_ID --quiet
                  terraform init -reconfigure
                  terraform apply -auto-approve
                '''
            }
        }
        stage('Build & Push Go App') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:/usr/local/bin:$PATH
                  gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
                  gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                  docker build -t $REGISTRY:$BUILD_NUMBER -t $REGISTRY:latest .
                  docker push $REGISTRY:$BUILD_NUMBER
                  docker push $REGISTRY:latest
                '''
            }
        }
        stage('Deploy to GKE') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:/usr/local/bin:$PATH
                  gcloud container clusters get-credentials my-go-cluster --zone $ZONE --project $PROJECT_ID || gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
                  kubectl -n $NAMESPACE create deployment go-app --image=$REGISTRY:$BUILD_NUMBER --port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  kubectl -n $NAMESPACE scale deployment go-app --replicas=2
                  kubectl -n $NAMESPACE rollout status deployment/go-app --timeout=300s
                  kubectl -n $NAMESPACE expose deployment go-app --name=go-app-service --type=LoadBalancer --port=80 --target-port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  kubectl get pods,svc -n $NAMESPACE
                '''
            }
        }
    }
}
