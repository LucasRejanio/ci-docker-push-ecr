#!/bin/bash

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
