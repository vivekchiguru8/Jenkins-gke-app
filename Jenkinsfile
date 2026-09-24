pipeline {
    agent any
    environment {
        PROJECT_ID = "project-10094705-9153-43d5-bb8"
        REGISTRY = "asia-south1-docker.pkg.dev/project-10094705-9153-43d5-bb8/my-app-repo/go-app"
        CLUSTER = "my-go-cluster"
        ZONE = "asia-south1-a"
        NAMESPACE = "go-app"
    }
    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Choose apply or destroy')
    }
    stages {
        stage('Setup Tools') {
            steps {
                sh '''
                  set -e
                  export PATH=/tmp/google-cloud-sdk/bin:/usr/local/bin:/tmp:$PATH
                  if ! command -v gcloud >/dev/null 2>&1; then
                    echo "Installing gcloud..."
                    curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/tmp
                    export PATH=/tmp/google-cloud-sdk/bin:$PATH
                  fi
                  if ! command -v terraform >/dev/null 2>&1; then
                    echo "Installing terraform..."
                    wget -q https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -O /tmp/tf.zip
                    unzip -o /tmp/tf.zip -d /tmp/
                    chmod +x /tmp/terraform
                    mv /tmp/terraform /usr/local/bin/terraform 2>/dev/null || sudo mv /tmp/terraform /usr/local/bin/ || true
                  fi
                  /tmp/google-cloud-sdk/bin/gcloud --version || gcloud --version
                  terraform version || /tmp/terraform version || /usr/local/bin/terraform version
                '''
            }
        }
        stage('Terraform Apply Infra') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:/usr/local/bin:$PATH
                  gcloud config set project $PROJECT_ID --quiet || /tmp/google-cloud-sdk/bin/gcloud config set project $PROJECT_ID --quiet
                  terraform init -reconfigure || /usr/local/bin/terraform init -reconfigure || /tmp/terraform init -reconfigure
                  terraform apply -auto-approve || /usr/local/bin/terraform apply -auto-approve
                '''
            }
        }
        stage('Build & Push Go App') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
                  gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet || /tmp/google-cloud-sdk/bin/gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
                  gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID || /tmp/google-cloud-sdk/bin/gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
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
                  gcloud container clusters get-credentials my-go-cluster --zone $ZONE --project $PROJECT_ID || gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID || /tmp/google-cloud-sdk/bin/gcloud container clusters get-credentials my-go-cluster --zone $ZONE --project $PROJECT_ID
                  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - || /tmp/google-cloud-sdk/bin/gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                  kubectl -n $NAMESPACE create deployment go-app --image=$REGISTRY:$BUILD_NUMBER --port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  kubectl -n $NAMESPACE scale deployment go-app --replicas=2
                  kubectl -n $NAMESPACE rollout status deployment/go-app --timeout=300s
                  kubectl -n $NAMESPACE expose deployment go-app --name=go-app-service --type=LoadBalancer --port=80 --target-port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  kubectl get pods,svc -n $NAMESPACE
                '''
            }
        }
        stage('Terraform Destroy Infra') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
                  terraform destroy -auto-approve || /usr/local/bin/terraform destroy -auto-approve
                '''
            }
        }
    }
}
