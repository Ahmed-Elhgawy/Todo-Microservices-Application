pipeline {
    agent any

    environment {
        DOCKER_INSTANCE_IP = "54.147.51.192"
        APP_REPO = "https://github.com/Ahmed-Elhgawy/todo-micrservice-app.git"
        ECR_REPO = "${ECR_REPO}"
    }

    stages {
        stage('build Docker Images') {
            steps {
                script {
                    sh 'docker build -t api ./todo-microservices/api/'
                    sh 'docker build -t worker ./todo-microservices/worker/'
                    sh 'docker build -t frontend ./todo-microservices/frontend/'
                }
            }
        }

        stage('Chech Container Security') {
            steps {
                script {
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format sarif -o trivy-api.sarif api || true'
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format sarif -o trivy-worker.sarif worker || true'
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format sarif -o trivy-frontend.sarif frontend || true'
                }

                recordIssues enabledForFailure: true, tools: [sarif(pattern: 'trivy-*.sarif')]

                archiveArtifacts artifacts: 'trivy-*.sarif', fingerprint: true
            }
        }

        stage('Connect to Docker Instance') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                if [ -d "~/todo-micrservice-app/.git" ]; then
                                    cd ~/todo-micrservice-app && git pull origin main
                                else
                                    git clone ${APP_REPO}
                                fi
                            "
                        """
                    }
                }
            }
        }

        stage('Deploy to Docker Instance') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                docker-compose -f todo-micrservice-app/todo-microservices/docker-compose.yaml up -d --build
                            "
                        """
                    }
                }
            }
        }

        stage('Chech the Application is running') {
            steps {
                script {
                    sleep 30
                    sh """
                        if curl -s -o /dev/null -w "%{http_code}" http://${DOCKER_INSTANCE_IP} | grep -q "200"; then
                            echo "✅ Application is running"                        
                        else
                            echo "❌ Application is NOT running"
                            exit 1
                        fi
                    """
                }
            }
        }

        stage('Destroy Test enviornment') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                docker-compose -f todo-micrservice-app/todo-microservices/docker-compose.yaml down
                            "
                        """
                    }
                }
            }
        }

        stage('Upload Image to ECR repos') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REPO}
                                docker tag todo-microservices-api-service ${ECR_REPO}/todo-api:latest
                                docker tag todo-microservices-worker ${ECR_REPO}/todo-worker:latest
                                docker tag todo-microservices-frontend-service ${ECR_REPO}/frontend:latest
                                docker push ${ECR_REPO}/todo-api:latest
                                docker push ${ECR_REPO}/todo-worker:latest
                                docker push ${ECR_REPO}/frontend:latest
                            "
                        """
                        
                    }
                }
            }
        }

        stage('Deploy to Kubernetes Cluster') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8s-jenkins-token', namespace: 'default', serverUrl: 'https://192.168.49.2:8443') {
                        sh 'kubectl apply -f kubernetes/.'
                    }
                }
            }
        }
    
    }
}