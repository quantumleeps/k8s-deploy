output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ecr_rag_pipeline_url" {
  description = "ECR repository URL for rag-pipeline"
  value       = aws_ecr_repository.rag_pipeline.repository_url
}

output "ecr_mcp_units_url" {
  description = "ECR repository URL for mcp-units"
  value       = aws_ecr_repository.mcp_units.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}
