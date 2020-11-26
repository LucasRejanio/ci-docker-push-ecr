# Docker push ecr
Essa pipeline Actions é uma solução automatizada de pull e push do Docker Hub para o serviço da AWS Elastic Container Registry (ECR). Para a pipeline ficar dinamica utilizamos objetos em um arquivo json, dessa forma podemos adicionar ou remover imagens sem precisar atualizar a pipeline diretamente. 

```json
[
    {
    "Profile":"prod",
    "Image":"datadog/agent:latest",
    "Ecr":"ECR_NAME:latest",
    "Service":"AWS_CI_ACCOUNT_ID.dkr.ecr.AWS_DEFAULT_REGION.amazonaws.com"
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
  schedule:
    - cron: "00 03 * * 0" # Midnight of everyday on BRT

env:
  AWS_DEFAULT_REGION: us-east-1
  AWS_DEFAULT_OUTPUT: json
  AWS_PROD_ACCOUNT_ID: ${{ secrets.AWS_CI_ACCOUNT_ID }}
  AWS_PROD_ACCESS_KEY_ID: ${{ secrets.AWS_CI_ACCESS_KEY_ID }}
  AWS_PROD_SECRET_ACCESS_KEY: ${{ secrets.AWS_CI_SECRET_ACCESS_KEY }}
  
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
          aws configure set aws_account_id ${AWS_PROD_ACCOUNT_ID} --profile prod \
          && aws configure set aws_access_key_id ${AWS_PROD_ACCESS_KEY_ID} --profile prod \
          && aws configure set aws_secret_access_key ${AWS_PROD_SECRET_ACCESS_KEY} --profile prod \
          && aws configure set aws_account_id ${AWS_QA_ACCOUNT_ID} --profile qa \
          && aws configure set aws_access_key_id ${AWS_QA_ACCESS_KEY_ID} --profile qa \
          && aws configure set aws_secret_access_key ${AWS_QA_SECRET_ACCESS_KEY} --profile qa \
          
      - name: Pull and push to ECR
        run: |
          for row in $(cat ./images-docker/images.json | jq -r '.[] | @base64'); do
              _jq() {
               echo ${row} | base64 --decode | jq -r ${1}
              }
              
              PROFILE_AWS=$(_jq '.Profile' | sed 's/"//g') \
              && IMAGE_NAME=$(_jq '.Image' | sed 's/"//g') \
              && ECR_NAME=$(_jq '.Ecr' | sed 's/"//g') \
              && SERVICE_NAME=$(_jq '.Service' | sed 's/"//g') \
              && echo "Configured variables" \
              && echo "Login account: " $PROFILE_AWS \
              && docker login \
              -u AWS \
              -p $(aws ecr --profile $PROFILE_AWS get-login-password) \
              https://$SERVICE_NAME \
              && echo "Starting pull" \
              && docker pull $IMAGE_NAME \
              && echo "Pull concluded" \
              && echo "Starting tag" \
              && docker tag $IMAGE_NAME $SERVICE_NAME/$ECR_NAME \
              && echo "Tag concluded" \
              && echo "Starting push" \
              && docker push $SERVICE_NAME/$ECR_NAME \
              && echo "Push concluded"
          done
```
