output "bation_instance_public_ip" {
  value = aws_instance.bastion-instance.public_ip
}

output "master_instance_ip" {
  value = aws_instance.master-instance.private_ip
}

output "worker_instance_ip" {
  value = aws_instance.worker-instance.private_ip
}

output "todo_api_repo_name" {
  value = aws_ecr_repository.ecr-todo-api.repository_url
}
output "todo_worker_repo_name" {
  value = aws_ecr_repository.ecr-todo-worker.repository_url
}
output "frontend_repo_name" {
  value = aws_ecr_repository.ecr-frontend.repository_url
}
