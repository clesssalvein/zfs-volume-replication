# Description
A simple shell script for incremental replication of ZFS volumes using their snapshots.

# Usage

- Create ZFS-Volume

```zfs create -V 10G raid1/vmail```

- Edit VARS
- Run

```./zfs-volume-replication.sh```
