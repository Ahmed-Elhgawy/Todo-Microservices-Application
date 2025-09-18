pipeline {
    agent any

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
                    sh 'trivy image --severity CRITICAL api'
                    sh 'trivy image --severity CRITICAL worker'
                    sh 'trivy image --severity CRITICAL frontend'
                }
            }
        }

        stage('Connect to Docker Instance') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@54.147.51.192 <<EOF
                                if [ -d "~/todo-micrservice-app" ]; then
                                    cd ~/todo-micrservice-app
                                    git pull origin main
                                else
                                    git clone https://github.com/Ahmed-Elhgawy/todo-micrservice-app.git
                                fi
                            EOF
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
                            ssh -o StrictHostKeyChecking=no ec2-user@54.147.51.192 <<EOF
                                docker-compose -f todo-micrservice-app/todo-microservices/docker-compose.yaml up -d --build
                            EOF
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
                        if curl -s -o /dev/null -w "%{http_code}" http://54.147.51.192 | grep -q "200"; then
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
                            ssh -o StrictHostKeyChecking=no ec2-user@54.147.51.192 <<EOF
                                docker-compose -f todo-micrservice-app/todo-microservices/docker-compose.yaml down
                            EOF
                        """
                    }
                }
            }
        }

        stage('Upload Image to ECR repos') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 054037114964.dkr.ecr.us-east-1.amazonaws.com'
                        sh 'docker tag todo-microservices-api-service 054037114964.dkr.ecr.us-east-1.amazonaws.com/todo-api:latest'
                        sh 'docker tag todo-microservices-worker 054037114964.dkr.ecr.us-east-1.amazonaws.com/todo-worker:latest'
                        sh 'docker tag todo-microservices-frontend-service 054037114964.dkr.ecr.us-east-1.amazonaws.com/frontend:latest'
                        sh 'docker push 054037114964.dkr.ecr.us-east-1.amazonaws.com/todo-api:latest'
                        sh 'docker push 054037114964.dkr.ecr.us-east-1.amazonaws.com/todo-worker:latest'
                        sh 'docker push 054037114964.dkr.ecr.us-east-1.amazonaws.com/frontend:latest'
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