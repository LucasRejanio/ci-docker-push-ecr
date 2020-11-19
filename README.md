# Docker push ecr
Docker pull from dockerhub and docker push to ecr aws

```yml
name: Docker pull from dockerhub and docker push to ecr aws

on:
  push:
    branches: [ main ]

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
