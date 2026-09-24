pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
    - name: jnlp
    image: jenkins/inbound-agent:latest
    - name: tools
    image: google/cloud-sdk:alpine
    command:
        - cat
    tty: true
'''
        }
    }
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
                container('tools') {
                    sh '''
                      set -e
                      apk add --no-cache docker-cli wget unzip
                      wget -q https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -O /tmp/tf.zip
                      unzip -o /tmp/tf.zip -d /usr/local/bin/
                      chmod +x /usr/local/bin/terraform
                      terraform version
                      gcloud --version
                      kubectl version --client || gcloud components install kubectl --quiet
                    '''
                }
            }
        }
        stage('Terraform Apply Infra') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('tools') {
                    sh '''
                      gcloud config set project $PROJECT_ID --quiet
                      terraform init -reconfigure
                      terraform apply -auto-approve
                    '''
                }
            }
        }
        stage('Build & Push Go App') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('tools') {
                    sh '''
                      gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
                      gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                      docker build -t $REGISTRY:$BUILD_NUMBER -t $REGISTRY:latest .
                      docker push $REGISTRY:$BUILD_NUMBER
                      docker push $REGISTRY:latest
                    '''
                }
            }
        }
        stage('Deploy to GKE') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('tools') {
                    sh '''
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
        stage('Terraform Destroy Infra') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                container('tools') {
                    sh '''
                      gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID || true
                      terraform destroy -auto-approve
                    '''
                }
            }
        }
    }
}
