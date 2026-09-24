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
        stage('Terraform Apply Infra') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/usr/local/bin:/tmp:$PATH
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
        stage('Terraform Destroy Infra') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                sh '''
                  export PATH=/tmp/google-cloud-sdk/bin:/tmp:$PATH
                  terraform init -reconfigure
                  terraform destroy -auto-approve
                '''
            }
        }
    }
}
