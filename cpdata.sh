#! /bin/bash

scp -i ~/.ssh/airbnb-spider.pem ubuntu@ec2-54-238-67-147.ap-northeast-1.compute.amazonaws.com:~/airbnb-spider/data/* ./data