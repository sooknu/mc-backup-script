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
   ```
2. Configure AWS CLI:
   ```bash
   aws configure
   ```
   Enter your **AWS Access Key**, **Secret Key**, **Region**, and output format.

3. Clone the repository:
   ```bash
   git clone https://github.com/YourUsername/mc-backup-script.git
   cd mc-backup-script
   ```

4. Make the script executable:
   ```bash
   chmod +x backup-to-s3.sh
   ```

## Configuration
Edit the script to match your setup:

- **S3 Bucket Name:**
  ```bash
  BUCKET_NAME="your-s3-bucket-name"
  ```
- **Backup Frequency (daily, weekly, monthly):**
  ```bash
  DEFAULT_FREQUENCY="daily"
  ```
- **List of Servers & Folders to Backup:**
  ```bash
  CONFIGURATION=(
      "/home/ubuntu/lobby:lobby"
      "/home/ubuntu/mc2:mc2"
      "/home/ubuntu/mc1:mc1"
      "/home/ubuntu/velocity:velocity"
  )
  ```
  Each entry follows the format:
  ```
  "server-folder:screen-session:frequency"
  ```
  `screen-session` is used to send commands like `save-off` to prevent world corruption.

## Usage
Run the script manually:
```bash
./backup-to-s3.sh
```
Or schedule it using `crontab`:
```bash
crontab -e
```
Add this line to run the backup **daily at 2 AM**:
```bash
0 2 * * * /path/to/backup-to-s3.sh
```

## How It Works
1. Notifies players of an incoming backup.
2. Pauses world writes (`save-off`) and forces a save (`save-all`).
3. Uses `rsync` to create a snapshot.
4. Compresses the snapshot into a `.tar.gz` archive.
5. Uploads the archive to S3 in a date-based folder.
6. Deletes backups older than **7** days (configurable).
7. Resumes world writes (`save-on`).
8. Logs all actions to `/home/ubuntu/backup-to-s3.log`.

## Restoring Backups
To restore a backup, download and extract the `.tar.gz` file:
```bash
aws s3 cp s3://your-s3-bucket/2024-02-13/server-backup.tar.gz .
tar -xzf server-backup.tar.gz -C /path/to/minecraft
```
Then restart your server.

## Troubleshooting
- **Check logs for errors:**
  ```bash
  cat /home/ubuntu/backup-to-s3.log
  ```
- **Manually verify S3 access:**
  ```bash
  aws s3 ls s3://your-s3-bucket/
  ```
- **Ensure `screen` sessions exist:**  
  ```bash
  screen -ls
  ```

## License
MIT License - Feel free to modify and improve!
