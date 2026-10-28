# DINIECO - AWS Free Tier Server Management Utility
# Region: ap-south-2 | Instance: t3.micro | Stack: dinieco-backend

param(
    [Parameter(Position=0)]
    [ValidateSet("status", "update", "stop", "start", "logs", "help")]
    [string]$Action = "status"
)

$Region = "ap-south-2"
$StackName = "dinieco-backend"
$S3Bucket = "dinieco-deploy-457778953440"
$AwsCli = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"

if (-not (Test-Path $AwsCli)) {
    $AwsCli = "aws"
}

function Get-InstanceId {
    & $AwsCli cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text
}

function Get-PublicIp {
    & $AwsCli cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='PublicIp'].OutputValue" --output text
}

switch ($Action) {
    "status" {
        Write-Host "Fetching DINIECO AWS Server Status..." -ForegroundColor Cyan
        $instanceId = Get-InstanceId
        $publicIp = Get-PublicIp
        $state = & $AwsCli ec2 describe-instances --instance-ids $instanceId --region $Region --query "Reservations[0].Instances[0].State.Name" --output text

        Write-Host "----------------------------------------------------"
        Write-Host "Instance ID : $instanceId"
        Write-Host "State       : $state" -ForegroundColor $(if ($state -eq "running") { "Green" } else { "Yellow" })
        Write-Host "Public IP   : $publicIp"
        Write-Host "API URL     : http://${publicIp}:8000/api/v1"
        Write-Host "Docs URL    : http://${publicIp}:8000/docs"
        Write-Host "Health URL  : http://${publicIp}:8000/health"
        Write-Host "----------------------------------------------------"

        if ($state -eq "running") {
            try {
                $health = Invoke-RestMethod -Uri "http://${publicIp}:8000/health" -TimeoutSec 4
                Write-Host "Live Health Check: Healthy ($($health | ConvertTo-Json -Compress))" -ForegroundColor Green
            } catch {
                Write-Host "Live Health Check: Server is still booting or starting uvicorn..." -ForegroundColor Yellow
            }
        }
    }

    "stop" {
        $instanceId = Get-InstanceId
        Write-Host "Stopping EC2 instance $instanceId to preserve Free Tier hours..." -ForegroundColor Yellow
        & $AwsCli ec2 stop-instances --instance-ids $instanceId --region $Region --output table
        Write-Host "Instance stopped. You will consume 0 compute hours while stopped." -ForegroundColor Green
    }

    "start" {
        $instanceId = Get-InstanceId
        Write-Host "Starting EC2 instance $instanceId..." -ForegroundColor Cyan
        & $AwsCli ec2 start-instances --instance-ids $instanceId --region $Region --output table
        Write-Host "Instance starting. Run '.\aws\manage.ps1 status' in ~30 seconds." -ForegroundColor Green
    }

    "update" {
        Write-Host "1. Packaging updated backend into dinieco-backend.tar.gz..." -ForegroundColor Cyan
        python -c "
import tarfile, os
with tarfile.open('dinieco-backend.tar.gz', 'w:gz', compresslevel=9) as tar:
    for root, dirs, files in os.walk('backend'):
        dirs[:] = [d for d in dirs if d not in ('__pycache__', '.pytest_cache', 'tests')]
        for f in files:
            if not f.endswith(('.pyc', '.pyo')):
                tar.add(os.path.join(root, f), arcname=os.path.relpath(os.path.join(root, f), 'backend'))
"
        Write-Host "2. Uploading package to S3 (s3://$S3Bucket)..." -ForegroundColor Cyan
        & $AwsCli s3 cp dinieco-backend.tar.gz "s3://${S3Bucket}/dinieco-backend.tar.gz" --region $Region
        Remove-Item "dinieco-backend.tar.gz" -ErrorAction SilentlyContinue

        Write-Host "3. Deploying and restarting service on EC2 via AWS Systems Manager..." -ForegroundColor Cyan
        $instanceId = Get-InstanceId
        $cmdId = & $AwsCli ssm send-command --instance-ids $instanceId --document-name "AWS-RunShellScript" --parameters 'commands=["aws s3 cp s3://dinieco-deploy-457778953440/dinieco-backend.tar.gz /tmp/dinieco-backend.tar.gz", "tar -xzf /tmp/dinieco-backend.tar.gz -C /opt/dinieco", "python3.11 -m pip install -r /opt/dinieco/requirements.txt", "systemctl restart dinieco.service"]' --region $Region --query "Command.CommandId" --output text
        
        Write-Host "Deployment triggered (Command ID: $cmdId). Service restarted successfully!" -ForegroundColor Green
    }

    "logs" {
        $instanceId = Get-InstanceId
        Write-Host "Fetching latest 40 lines of DINIECO journalctl service logs..." -ForegroundColor Cyan
        & $AwsCli ssm send-command --instance-ids $instanceId --document-name "AWS-RunShellScript" --parameters 'commands=["journalctl -u dinieco.service -n 40 --no-pager"]' --region $Region --query "Command.CommandId" --output text
    }

    "help" {
        Write-Host "DINIECO AWS Free Tier Server Management Commands:"
        Write-Host "  .\aws\manage.ps1 status  - Show server IP, status, and health check"
        Write-Host "  .\aws\manage.ps1 update  - Push latest local backend code to AWS"
        Write-Host "  .\aws\manage.ps1 stop    - Stop EC2 instance to preserve Free Tier hours"
        Write-Host "  .\aws\manage.ps1 start   - Start EC2 instance"
        Write-Host "  .\aws\manage.ps1 logs    - View live backend application logs"
    }
}
