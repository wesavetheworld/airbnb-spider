#! /bin/bash

ssh -i ~/.ssh/airbnb-spider.pem ubuntu@ec2-54-238-67-147.ap-northeast-1.compute.amazonaws.com "tar -cxvf data.tar airbnb-spider/data"
scp -i ~/.ssh/airbnb-spider.pem ubuntu@ec2-54-238-67-147.ap-northeast-1.compute.amazonaws.com:~/data.tar .
ssh -i ~/.ssh/airbnb-spider.pem ubuntu@ec2-54-238-67-147.ap-northeast-1.compute.amazonaws.com "rm data.tar"
tar -zxvf data.tar
rm data.tar


