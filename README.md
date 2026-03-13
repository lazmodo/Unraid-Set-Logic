# Unraid-Set-Logic
### Updated 3/13/26

## Usage & Scheduling
These scripts are designed to be managed via the User Scripts plugin in Unraid. Below are the recommended schedules to balance performance and visibility.

---

## 💾 Flash Backup with GFS Rotation (`Flash_Backup_with_Rotation.sh`)

This script manages a multi-tier backup of the Unraid Flash drive. Instead of simple deletion, it uses a **Grandfather-Father-Son (GFS)** rotation scheme to provide long-term recovery with minimal storage overhead.

### 🛠 How it Works
* **Hardlink Efficiency**: The script uses `cp -al`. This creates **Hardlinks** for unchanged files. It provides a 6-month history while consuming only slightly more space than a single backup.
* **Integrity Check**: Includes a `mountpoint` check to ensure the Flash drive is mounted before attempting a backup, preventing "empty" backups if the USB drops offline.
* **Permission Mapping**: Automatically runs `newperms` on the destination to ensure backups are accessible via SMB/Network shares.

### 📅 Retention Policy
* **Daily**: Last **7 days** of snapshots (`daily.0` through `daily.6`).
* **Weekly**: Every Sunday, the snapshot is promoted to a weekly archive (Last **4 weeks**).
* **Monthly**: On the 1st of each month, the snapshot is promoted to a monthly archive (Last **6 months**).

### 🖥 Usage in User Scripts
Set this to run **Daily** (typically scheduled at night).

### Recommended Schedule: 
* Run Daily. After initial backup, this should only take a few seconds

---

## 💾 Daily Media Inventory (`Backup_Media_Physical_Inventory.sh`)

This script serves as the **Physical Manifest** for your media library, focusesing on "where" it is and ensures the inventory is safely backed up.

### 🛠 How it Works
* **Deep Scan**: This performs a thorough scan to ensure no file is missed in the inventory. The `Dynamix Cache Directories` plugin helps speed this script up tremendously.
* **Redundant Logging**: Saves the inventory list to a dedicated backup location, ensuring you have a text-based record of your library even if the primary appdata or metadata is lost.

### 📅 Recommended Usage
* **Daily**: Set this to run after your "Mover" for the night.

---

## 🧩 TV Seasons Split Audit (`TV_Seasons_Split_Array_Disk.sh`)

This is a specialized diagnostic tool designed to identify *season fragmentation* across the array. It detects TV Seasons that have been "split" across multiple physical disks, which can lead to unnecessary disk spin-ups and latency during binge-watching.

### 🛠 How it Works
* **Cross-Disk Analysis**: Scans the `/mnt/disk*` paths to find folders that exist on more than one physical drive.
* **Fragmentation Reporting**: Generates a clear report of which series and seasons are split, allowing you to use tools like `unbalance` to consolidate them onto a single disk.

### 📅 Recommended Usage
* **Weekly**: Best run weekly.
* **Manual**: Run this after a large import of new seasons to ensure your "Split Level" settings in Unraid are working as intended.

