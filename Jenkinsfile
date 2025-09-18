pipeline {
    agent any

    environment {
        DOCKER_INSTANCE_IP = "54.91.94.212"
        APP_REPO = "https://github.com/Ahmed-Elhgawy/todo-microservice-app.git"
        APP_REPO_SSH = "git@github.com:Ahmed-Elhgawy/todo-microservice-app.git"
        ECR_REPO = "054037114964.dkr.ecr.us-east-1.amazonaws.com"
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
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format template --template "@/usr/bin/html.tpl" -o trivy-api.html api'
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format template --template "@/usr/bin/html.tpl" -o trivy-worker.html worker'
                    sh 'trivy image --severity MEDIUM,HIGH,CRITICAL --format template --template "@/usr/bin/html.tpl" -o trivy-frontend.html frontend'
                }
            }
            post {
                success {
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'trivy-api.html,trivy-worker.html,trivy-frontend.html',
                        reportName: 'Trivy Vulnerability Report',
                        keepAll: true,
                        alwaysLinkToLastBuild: true,
                        allowMissing: false
                    ])
                }
            }
        }

        stage('Connect to Docker Instance') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                if [ -d "~/todo-microservice-app/.git" ]; then
                                    cd ~/todo-microservice-app && git pull origin main
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
                                docker-compose -f todo-microservice-app/todo-microservices/docker-compose.yaml up -d --build
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
            post {
                success {
                    slackSend color: "good", message: "✅ The Test successed"
                }
                failure {
                    slackSend color: "danger", message: "❌ The Test Failed"
                }
            }
        }

        stage('Destroy Test enviornment') {
            steps {
                script {
                    sshagent(credentials: ['docker_instance_privateKey']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${DOCKER_INSTANCE_IP} "
                                docker-compose -f todo-microservice-app/todo-microservices/docker-compose.yaml down
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
                                docker tag todo-microservices-api-service ${ECR_REPO}/todo-api:${env.BUILD_NUMBER}
                                docker tag todo-microservices-worker ${ECR_REPO}/todo-worker:${env.BUILD_NUMBER}
                                docker tag todo-microservices-frontend-service ${ECR_REPO}/frontend:${env.BUILD_NUMBER}
                                docker push ${ECR_REPO}/todo-api:${env.BUILD_NUMBER}
                                docker push ${ECR_REPO}/todo-worker:${env.BUILD_NUMBER}
                                docker push ${ECR_REPO}/frontend:${env.BUILD_NUMBER}
                            "
                        """
                    }
                }
            }
        }

        stage('Manual Gate') {
            steps {
                slackSend color: 'good', message: "Waiting for Admin Response..."
                script {
                    def userInput = input(
                        id: 'UserInput',
                        message: "Choose the next action:",
                        parameters: [
                            choice(name: 'ACTION', choices: ['Continue', 'Abort'], description: 'Select what to do')
                        ]
                    )
                    echo "You chose: ${userInput}"
                    if (userInput == 'Abort') {
                        currentBuild.result = 'ABORTED'
                        error("Pipeline aborted by user")
                    }
                }
            }
        }

        stage('Update K8s Manifest') {
            steps {
                script {
                    sh """
                       sed -i 's|${ECR_REPO}/todo-api:[^[:space:]]*|${ECR_REPO}/todo-api:${env.BUILD_NUMBER}|' kubernetes/deployments.yaml
                       sed -i 's|${ECR_REPO}/todo-worker:[^[:space:]]*|${ECR_REPO}/todo-worker:${env.BUILD_NUMBER}|' kubernetes/deployments.yaml
                       sed -i 's|${ECR_REPO}/frontend:[^[:space:]]*|${ECR_REPO}/frontend:${env.BUILD_NUMBER}|' kubernetes/deployments.yaml
                    """
                }
            }
        }

        stage('Push Updated Manifest to GitHub') {
            steps {
                script {
                    sshagent(['gethub-private-key']) {
                        sh """
                            git config user.name "jenkins-bot"
                            git config user.email "jenkins@example.com"

                            git add kubernetes/deployments.yaml
                            git commit -m "Update image tag to ${BUILD_NUMBER}"
                            git push ${APP_REPO_SSH} HEAD:main
                        """
                    }
                }
            }
        }
    
    }
    post {
        success {
            slackSend color: 'good', message: "✅ SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        }
        failure {
            slackSend color: 'danger', message: "❌ FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        }
        unstable {
            slackSend color: 'warning', message: "⚠️ UNSTABLE: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        }
    }
}