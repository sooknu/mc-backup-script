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
