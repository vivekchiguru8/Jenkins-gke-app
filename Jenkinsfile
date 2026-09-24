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
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
    }
    stages {
        stage('Setup Tools') {
            steps {
                container('tools') {
                    sh '''
                      apk add --no-cache docker-cli wget unzip
                      wget -q https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -O /tmp/tf.zip
                      unzip -o /tmp/tf.zip -d /usr/local/bin/
                      chmod +x /usr/local/bin/terraform
                      terraform version
                      gcloud --version
                    '''
                }
            }
        }
        stage('Terraform Init') {
            steps {
                container('tools') {
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
                container('tools') { sh 'terraform plan -out=tfplan' }
            }
        }
        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('tools') { sh 'terraform apply -auto-approve tfplan' }
            }
        }
        stage('Build & Push') {
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
        stage('Deploy to go-app') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                container('tools') {
                    sh '''
                      gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID || gcloud container clusters get-credentials jenkins-cluster --zone $ZONE --project $PROJECT_ID
                      kubectl -n $NAMESPACE create deployment go-app --image=$REGISTRY:$BUILD_NUMBER --port=8080 --dry-run=client -o yaml | kubectl apply -f -
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
                container('tools') {
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
