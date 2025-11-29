#!/bin/bash

APP_BUCKET="${app_bucket_name}"
JAR_KEY="${jar_key}"
LOG_BUCKET="${logs_bucket}"

JAR_NAME=$(basename "$JAR_KEY")
LOG_PATH="/var/log/myapp"
JAR_PATH="/home/ec2-user/$JAR_NAME"

# 1. Install Java and Basic Tools
yum update -y
yum install -y java-17-amazon-corretto-headless awscli jq ruby wget

mkdir -p "$LOG_PATH"

# 2. Install CodeDeploy Agent (CRITICAL FOR ASSIGNMENT)
cd /home/ec2-user
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
service codedeploy-agent start

# 3. Existing App Logic (Optional now, but good for backup)
sleep 5
aws s3 cp "s3://$APP_BUCKET/$JAR_KEY" "$JAR_PATH"
chmod +x "$JAR_PATH"
nohup java -jar "$JAR_PATH" --server.port=8080 > "$LOG_PATH/myapp.log" 2>&1 &

# 4. Setup Cron job for Logs
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
CRON_JOB_FILE="/home/ec2-user/upload_logs.sh"

cat << EOF > $CRON_JOB_FILE
#!/bin/bash
aws s3 cp "$LOG_PATH/myapp.log" "s3://$LOG_BUCKET/ec2-logs/$INSTANCE_ID/\$(date +\%Y-\%m-\%d-\%H\%M).log"
EOF

chmod +x $CRON_JOB_FILE
(crontab -l 2>/dev/null; echo "*/5 * * * * $CRON_JOB_FILE") | crontab -