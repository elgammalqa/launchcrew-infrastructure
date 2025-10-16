.PHONY: help init-dev init-prod plan-dev plan-prod apply-dev apply-prod destroy-dev destroy-prod fmt validate

help:
	@echo "Terraform GKE Management"
	@echo ""
	@echo "Available targets:"
	@echo "  init-dev       - Initialize dev environment"
	@echo "  init-prod      - Initialize prod environment"
	@echo "  plan-dev       - Plan dev changes"
	@echo "  plan-prod      - Plan prod changes"
	@echo "  apply-dev      - Apply dev changes"
	@echo "  apply-prod     - Apply prod changes"
	@echo "  destroy-dev    - Destroy dev resources"
	@echo "  destroy-prod   - Destroy prod resources"
	@echo "  fmt            - Format all Terraform files"
	@echo "  validate       - Validate all configurations"

init-dev:
	cd environments/dev && terraform init

init-prod:
	cd environments/prod && terraform init

plan-dev:
	cd environments/dev && terraform plan -var-file="terraform.tfvars"

plan-prod:
	cd environments/prod && terraform plan -var-file="terraform.tfvars"

apply-dev:
	cd environments/dev && terraform apply -var-file="terraform.tfvars"

apply-prod:
	cd environments/prod && terraform apply -var-file="terraform.tfvars"

destroy-dev:
	cd environments/dev && terraform destroy -var-file="terraform.tfvars"

destroy-prod:
	cd environments/prod && terraform destroy -var-file="terraform.tfvars"

fmt:
	terraform fmt -recursive .

validate:
	cd environments/dev && terraform validate
	cd environments/prod && terraform validate

cost-estimate-dev:
	@echo "Estimated monthly cost for DEV:"
	@echo "  - e2-standard-4 spot nodes (1-2): ~$25-50/month (spot)"
	@echo "  - Network egress: ~$5-10/month"
	@echo "  - Load balancer: ~$18/month"
	@echo "  - Total: ~$48-78/month"

cost-estimate-prod:
	@echo "Estimated monthly cost for PROD:"
	@echo "  - e2-small nodes (2-4): ~$50-100/month"
	@echo "  - Network egress: ~$20-30/month"
	@echo "  - Load balancer: ~$18/month"
	@echo "  - Total: ~$88-148/month"
