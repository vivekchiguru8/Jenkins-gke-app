pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-ksa
  containers:
    - name: main
    image: google/cloud-sdk:alpine
    command:
        - cat
    tty: true
    securityContext:
      privileged: true
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
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
    }
    stages {
        stage('Setup Tools') {
            steps {
                container('main') {
                    sh '''
                      apk add --no-cache docker-cli terraform kubectl --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community || apk add --no-cache docker-cli
                      wget -qO /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip
                      unzip -o /tmp/terraform.zip -d /usr/local/bin/
                      chmod +x /usr/local/bin/terraform
                      gcloud --version
                      docker --version
                      terraform version
                      kubectl version --client
                    '''
                }
            }
        }
        stage('Terraform Init') {
            steps {
                container('main') {
                    sh '''
                      gcloud config set project $PROJECT_ID --quiet
                      terraform init -reconfigure
                    '''
                }
            }
        }
        stage('Terraform Plan') {
            when { expression { params.ACTION == 'plan' || params.ACTION == 'apply' } }
            steps {
                container('main') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('main') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
        stage('Build & Push') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('main') {
                    sh '''
                      gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
                      gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID || gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                      docker build -t $REGISTRY:$BUILD_NUMBER -t $REGISTRY:latest .
                      docker push $REGISTRY:$BUILD_NUMBER
                      docker push $REGISTRY:latest
                    '''
                }
            }
        }
        stage('Deploy to go-app') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('main') {
                    sh '''
                      gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID || gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                      kubectl -n $NAMESPACE create deployment go-app --image=$REGISTRY:$BUILD_NUMBER --port=8080 --dry-run=client -o yaml | kubectl apply -f -
                      kubectl -n $NAMESPACE set image deployment/go-app go-app=$REGISTRY:$BUILD_NUMBER
                      kubectl -n $NAMESPACE rollout status deployment/go-app --timeout=300s
                      kubectl -n $NAMESPACE expose deployment go-app --name=go-app-service --type=LoadBalancer --port=80 --target-port=8080 --dry-run=client -o yaml | kubectl apply -f -
                      kubectl get pods,svc -n $NAMESPACE
                    '''
                }
            }
        }
        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                container('main') {
                    sh '''
                      gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID || true
                      kubectl delete svc go-app-service -n $NAMESPACE --ignore-not-found=true || true
                      kubectl delete deployment go-app -n $NAMESPACE --ignore-not-found=true || true
                      terraform destroy -auto-approve
                    '''
                }
            }
        }
    }
}
