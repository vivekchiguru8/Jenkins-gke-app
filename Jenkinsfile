pipeline {
    agent any
    environment {
        PROJECT_ID = "project-10094705-9153-43d5-bb8"
        REGISTRY = "asia-south1-docker.pkg.dev/project-10094705-9153-43d5-bb8/my-app-repo/go-app"
        CLUSTER = "my-go-cluster"
        ZONE = "asia-south1-a"
        NAMESPACE = "go-app"
        CLOUDSDK_CORE_DISABLE_PROMPTS = "1"
        PATH = "/tmp/google-cloud-sdk/bin:/usr/local/bin:/tmp:$PATH"
    }
    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Choose apply or destroy')
    }
    stages {
        stage('Setup Tools') {
            steps {
                sh '''
                  set -e
                  mkdir -p /tmp
                  echo "=== GCloud portable install ==="
                  if [ ! -f /tmp/google-cloud-sdk/bin/gcloud ]; then
                    cd /tmp
                    wget -q https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz -O gcloud.tar.gz
                    tar -xzf gcloud.tar.gz
                    ./google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=false --bash-completion=false
                  fi
                  /tmp/google-cloud-sdk/bin/gcloud --version

                  echo "=== Terraform portable ==="
                  if [ ! -f /tmp/terraform ]; then
                    wget -q https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -O /tmp/tf.zip
                    unzip -o /tmp/tf.zip -d /tmp/
                    chmod +x /tmp/terraform
                  fi
                  /tmp/terraform version

                  echo "=== kubectl via gcloud ==="
                  /tmp/google-cloud-sdk/bin/gcloud components install kubectl --quiet || true
                  /tmp/google-cloud-sdk/bin/kubectl version --client || kubectl version --client || true
                '''
            }
        }
        stage('Terraform Apply Infra') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
                  gcloud config set project $PROJECT_ID --quiet
                  terraform init -reconfigure || /tmp/terraform init -reconfigure
                  terraform apply -auto-approve || /tmp/terraform apply -auto-approve
                '''
            }
        }
        stage('Build & Push Go App') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
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
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
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
