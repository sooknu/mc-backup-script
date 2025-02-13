# Minecraft Backup Script (rsync + S3)

This script creates consistent backups of Minecraft servers using `rsync`, compresses them, and uploads them to an Amazon S3 bucket. It minimizes downtime by pausing world saves instead of stopping the server.

## Features
- Uses `rsync` to create efficient snapshots
- Pauses and resumes world saves instead of shutting down servers
- Compresses backups before uploading to S3
- Deletes old backups, keeping only the last **7** backups (configurable)
- Supports multiple servers with different backup frequencies (daily, weekly, monthly)
- Logs all operations for troubleshooting
- Gracefully handles script interruptions (SIGINT/SIGTERM)

## Requirements
- Linux (Ubuntu/Debian recommended)
- `aws-cli` (configured with access to an S3 bucket)
- `rsync` for efficient incremental backups
- `screen` for sending commands to Minecraft servers
- Git (for version control if needed)

## Installation
1. Install dependencies:
   ```bash
   sudo apt update
   sudo apt install awscli rsync screen -y

Configure AWS CLI:

bash
Copy
Edit
aws configure
Enter your AWS Access Key, Secret Key, Region, and output format.

Clone the repository:

bash
Copy
Edit
git clone https://github.com/YourUsername/mc-backup-script.git
cd mc-backup-script
Make the script executable:

bash
Copy
Edit
chmod +x backup-to-s3.sh
Configuration
Edit the script to match your setup:

S3 Bucket Name:
bash
Copy
Edit
BUCKET_NAME="your-s3-bucket-name"
Backup Frequency (daily, weekly, monthly):
bash
Copy
Edit
DEFAULT_FREQUENCY="daily"
List of Servers & Folders to Backup:
bash
Copy
Edit
CONFIGURATION=(
    "/home/ubuntu/lobby:lobby"
    "/home/ubuntu/mc2:mc2"
    "/home/ubuntu/mc1:mc1"
    "/home/ubuntu/velocity:velocity"
)
Each entry follows the format:
arduino
Copy
Edit
"server-folder:screen-session:frequency"
screen-session is used to send commands like save-off to prevent world corruption.
Usage
Run the script manually:

bash
Copy
Edit
./backup-to-s3.sh
Or schedule it using crontab:

bash
Copy
Edit
crontab -e
Add this line to run the backup daily at 2 AM:

bash
Copy
Edit
0 2 * * * /path/to/backup-to-s3.sh
How It Works
Notifies players of an incoming backup.
Pauses world writes (save-off) and forces a save (save-all).
Uses rsync to create a snapshot.
Compresses the snapshot into a .tar.gz archive.
Uploads the archive to S3 in a date-based folder.
Deletes backups older than 7 days (configurable).
Resumes world writes (save-on).
Logs all actions to /home/ubuntu/backup-to-s3.log.
Restoring Backups
To restore a backup, download and extract the .tar.gz file:

bash
Copy
Edit
aws s3 cp s3://your-s3-bucket/2024-02-13/server-backup.tar.gz .
tar -xzf server-backup.tar.gz -C /path/to/minecraft
Then restart your server.

Troubleshooting
Check logs for errors:
bash
Copy
Edit
cat /home/ubuntu/backup-to-s3.log
Manually verify S3 access:
bash
Copy
Edit
aws s3 ls s3://your-s3-bucket/
Ensure screen sessions exist:
bash
Copy
Edit
screen -ls
License
MIT License - Feel free to modify and improve!
