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
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
    }
    stages {
        stage('Terraform Init') {
            steps {
                sh '''
                  gcloud config set project $PROJECT_ID --quiet
                  terraform init -reconfigure
                '''
            }
        }
        
        stage('Terraform Plan') {
            when { expression { params.ACTION == 'plan' || params.ACTION == 'apply' } }
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
        
        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }

        stage('Build & Push Image') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
                  docker build -t $REGISTRY:$BUILD_NUMBER -t $REGISTRY:latest .
                  docker push $REGISTRY:$BUILD_NUMBER
                  docker push $REGISTRY:latest
                '''
            }
        }

        stage('Deploy to Existing go-app NS') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                  gcloud container clusters get-credentials $CLUSTER --zone $ZONE --project $PROJECT_ID
                  
                  # Deploy to YOUR existing go-app namespace
                  kubectl -n $NAMESPACE create deployment go-app --image=$REGISTRY:$BUILD_NUMBER --port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  kubectl -n $NAMESPACE set image deployment/go-app go-app=$REGISTRY:$BUILD_NUMBER
                  kubectl -n $NAMESPACE set env deployment/go-app PORT=8080
                  kubectl -n $NAMESPACE scale deployment go-app --replicas=2
                  kubectl -n $NAMESPACE rollout status deployment/go-app --timeout=300s
                  kubectl -n $NAMESPACE expose deployment go-app --name=go-app-service --type=LoadBalancer --port=80 --target-port=8080 --dry-run=client -o yaml | kubectl apply -f -
                  
                  echo "=== Deployment in go-app namespace ==="
                  kubectl get pods -n $NAMESPACE
                  kubectl get svc -n $NAMESPACE
                '''
            }
        }

        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
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