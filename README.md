# Docker push ecr
Essa pipeline Actions é uma solução automatizada de pull e push do Docker Hub para o serviço da AWS Elastic Container Registry (ECR). Para a pipeline ficar dinamica utilizamos objetos em um arquivo json, dessa forma podemos adicionar ou remover imagens sem precisar atualizar a pipeline diretamente. 

## Evolução da construção

```yml
name: Docker pull from dockerhub and docker push to ecr aws

on:
  schedule:
    - cron: "00 03 * * *" # Midnight of everyday on BRT

env:
  AWS_DEFAULT_REGION: us-east-1
  AWS_DEFAULT_OUTPUT: json
  AWS_ACCOUNT_ID: ${{ secrets.AWS_CI_ACCOUNT_ID }}
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_CI_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_CI_SECRET_ACCESS_KEY }}
  CONTAINER_IMAGE: datadog-agent

jobs:
  build-and-push:
    runs-on: ubuntu-20.04

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Setup ECR
        run: |
          docker login \
          -u AWS \
          -p $(aws ecr get-login-password) \
          https://$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
          
      - name: Docker pull image
        run: |
          docker pull datadog/agent:latest
        working-directory: ./datadog-agent
        
      - name: Docker tag in the ECS
        run: |
          docker tag datadog/agent:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$CONTAINER_IMAGE:latest
        working-directory: ./datadog-agent

      - name: Push to ECR
        run: |
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$CONTAINER_IMAGE:latest
        working-directory: ./datadog-agent
```
