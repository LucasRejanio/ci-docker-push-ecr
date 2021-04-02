<img alt="Docker" src="https://img.shields.io/badge/docker%20-%230db7ed.svg?&style=for-the-badge&logo=docker&logoColor=white"/> <img alt="GitHub Actions" src="https://img.shields.io/badge/github%20actions%20-%232671E5.svg?&style=for-the-badge&logo=github%20actions&logoColor=white"/>

[![build](https://img.shields.io/wercker/build/wercker/go-wercker-api.svg)](https://github.com/LucasRejanio/docker-push-ecr/actions)

# Docker push ecr
Essa pipeline Actions é uma solução automatizada de pull e push do Docker Hub para o serviço da AWS Elastic Container Registry (ECR). Para a pipeline ficar dinamica utilizamos objetos em um arquivo json, dessa forma podemos adicionar ou remover imagens sem precisar atualizar a pipeline diretamente. 

```json
[
    {
        "profile":"prod",
        "dockerhub_image_name":"datadog/agent:latest",
        "ecr_image_name":"datadog-agent:latest",
        "ecr_host":"033846053144.dkr.ecr.us-east-1.amazonaws.com"
    }
]
```

## Evolução da construção
Primeiro realizei todo o processo de maneira manual, setando valores fixos. 

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

Logo depois eu comecei a trabalhar com esses dados em um arquivo Json para entender o funcionamento dentro do Github Actions. 

```yml
name: Docker pull from dockerhub and docker push to ecr aws

on:
  push:
    branches: [ main ]

env:
  AWS_DEFAULT_REGION: us-east-1
  AWS_DEFAULT_OUTPUT: json
  AWS_CI_ACCOUNT_ID: ${{ secrets.AWS_CI_ACCOUNT_ID }}
  AWS_CI_ACCESS_KEY_ID: ${{ secrets.AWS_CI_ACCESS_KEY_ID }}
  AWS_CI_SECRET_ACCESS_KEY: ${{ secrets.AWS_CI_SECRET_ACCESS_KEY }}
  
  AWS_QA_ACCOUNT_ID: ${{ secrets.AWS_QA_ACCOUNT_ID }}
  AWS_QA_ACCESS_KEY_ID: ${{ secrets.AWS_QA_ACCESS_KEY_ID }}
  AWS_QA_SECRET_ACCESS_KEY: ${{ secrets.AWS_QA_SECRET_ACCESS_KEY }}
  

jobs:
  build-and-push:
    runs-on: ubuntu-20.04

    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      
      - name: Configure environments
        run: |
          aws configure set aws_account_id ${AWS_CI_ACCOUNT_ID} --profile prod \
          && aws configure set aws_access_key_id ${AWS_CI_ACCESS_KEY_ID} --profile prod \
          && aws configure set aws_secret_access_key ${AWS_CI_SECRET_ACCESS_KEY} --profile prod \
          && aws configure set aws_account_id ${AWS_QA_ACCOUNT_ID} --profile qa \
          && aws configure set aws_access_key_id ${AWS_QA_ACCESS_KEY_ID} --profile qa \
          && aws configure set aws_secret_access_key ${AWS_QA_SECRET_ACCESS_KEY} --profile qa \

      #Enviroment CI
      - name: Setup ECR enviromment CI 
        run: |
          docker login \
          -u AWS \
          -p $(aws ecr --profile prod get-login-password) \
          https://$AWS_CI_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      
      - name: Parse Json and set env 
        run: |
          echo "IMAGE_NAME=$(cat ./images-docker/images.json | jq '.[].Image' | sed 's/"//g')" >> $GITHUB_ENV \
          && echo "SERVICE_NAME=$(cat ./images-docker/images.json | jq '.[].Service' | sed 's/"//g')" >> $GITHUB_ENV 
      
      - name: Docker pull image 
        run: |
          docker pull $IMAGE_NAME
        
      - name: Docker tag in the ECS
        run: |
          docker tag $IMAGE_NAME $SERVICE_NAME
```

E por fim, deixei tudo de uma maneira dinâmica, passando todos os parametros nescessários para o processo direto no Json.

```yml
name: Pull from Dockerhub and push to AWS ECR

on:
  push:
    branches: [ main ]
    
env:
  AWS_DEFAULT_REGION: us-east-1
  AWS_DEFAULT_OUTPUT: json
  AWS_CI_ACCOUNT_ID: ${{ secrets.AWS_CI_ACCOUNT_ID }}
  AWS_CI_ACCESS_KEY_ID: ${{ secrets.AWS_CI_ACCESS_KEY_ID }}
  AWS_CI_SECRET_ACCESS_KEY: ${{ secrets.AWS_CI_SECRET_ACCESS_KEY }}
  
  AWS_QA_ACCOUNT_ID: ${{ secrets.AWS_QA_ACCOUNT_ID }}
  AWS_QA_ACCESS_KEY_ID: ${{ secrets.AWS_QA_ACCESS_KEY_ID }}
  AWS_QA_SECRET_ACCESS_KEY: ${{ secrets.AWS_QA_SECRET_ACCESS_KEY }}

jobs:
  build-and-push:
    runs-on: ubuntu-20.04

    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      
      - name: Configure environments
        run: |
          aws configure set aws_account_id ${AWS_CI_ACCOUNT_ID} --profile prod \
          && aws configure set aws_access_key_id ${AWS_CI_ACCESS_KEY_ID} --profile prod \
          && aws configure set aws_secret_access_key ${AWS_CI_SECRET_ACCESS_KEY} --profile prod \
          && aws configure set aws_account_id ${AWS_QA_ACCOUNT_ID} --profile qa \
          && aws configure set aws_access_key_id ${AWS_QA_ACCESS_KEY_ID} --profile qa \
          && aws configure set aws_secret_access_key ${AWS_QA_SECRET_ACCESS_KEY} --profile qa \
          
      - name: Pull and push to ECR
        run: |
          for row in $(cat ./images-docker/images.json | jq -r '.[] | @base64'); do
              _jq() {
               echo ${row} | base64 --decode | jq -r ${1}
              }
              
              PROFILE_AWS=$(_jq '.profile' | sed 's/"//g') \
              && IMAGE_NAME=$(_jq '.dockerhub_image_name' | sed 's/"//g') \
              && ECR_NAME=$(_jq '.ecr_image_name' | sed 's/"//g') \
              && SERVICE_NAME=$(_jq '.ecr_host' | sed 's/"//g') \
              && docker login -u AWS -p $(aws ecr --profile $PROFILE_AWS get-login-password) https://$SERVICE_NAME \
              && docker pull $IMAGE_NAME \
              && docker tag $IMAGE_NAME $SERVICE_NAME/$ECR_NAME \
              && docker push $SERVICE_NAME/$ECR_NAME \
              && echo "Process completed on account:" $PROFILE_AWS "with the image:" $IMAGE_NAME "and ECR:" $ECR_NAME
          done
```
