#!/bin/bash

#####
#
# *zfs-volume-replication* v2023.02.02 by @ClessAlvein
#
#####


# VARS
zfsVolOriginalFullName="d1/vmail";
zfsVolReplicaFullName="d2/vmail_replica";
zfsSnapsNewestQtyToLeave="7";

# get snapshots quantity
snapsOriginalQty=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
        | awk 'END {print NR}'`
snapsReplicaQty=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolReplicaFullName} \
        | awk 'END {print NR}'`

# debug
echo "Original Volume snaps Quantity: ${snapsOriginalQty}";
echo "Replica Volume snaps Quantity: ${snapsReplicaQty}";

# get the latest snaps of the original and replica volumes
snapOriginalLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
        | awk 'NR==1 {print $0}'`;
snapReplicaLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolReplicaFullName} \
        | awk 'NR==1 {print $0}'`;
snapOriginalLatestShortName=${snapOriginalLatestFullName#*@};
snapReplicaLatestShortName=${snapReplicaLatestFullName#*@};

# debug
echo "Original latest snap Full name: ${snapOriginalLatestFullName}";
echo "Replica latest snap Full name: ${snapReplicaLatestFullName}";
echo "Original latest snap Short name: ${snapOriginalLatestShortName}";
echo "Replica latest snap Short name: ${snapReplicaLatestShortName}";

# if there is NO snaps at original Volume
if [ ${snapsOriginalQty} -eq 0 ]; then
    # debug
    echo "--- There is no snaps on Original Replica! ---";
    echo "--- Creating New First Latest snap on Original Replica... ---";

    # create snap
    zfs snapshot ${zfsVolOriginalFullName}@auto-`date +%Y%m%d-%H%M%S`;

    # get snap name
    snapOriginalNewLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName}`;

    # debug
    echo "Original New Latest snap created: ${snapOriginalNewLatestFullName}";

    # if there are some snaps on Replica Volume
    if [ ${snapsReplicaQty} -gt 0 ]; then
        # debug
        echo "--- Destroying all snaps on Replica Volume... ---";

        # destroy all snaps at Replica Volume
        zfs destroy ${zfsVolReplicaFullName}@%;
    fi

    # debug
    echo "--- Making replication... ---";

    # make replication
    zfs send -Pev ${snapOriginalNewLatestFullName} | zfs recv -F ${zfsVolReplicaFullName};
fi

# if there is ONE or MORE snaps at original Volume
if [ ${snapsOriginalQty} -ge 1 ]; then
    # if the Latest snaps on Original Volume and Replica Volume have equal names
    if [[ "${snapOriginalLatestShortName}" == "${snapReplicaLatestShortName}" ]]; then
        # debug
        echo "Latest snap names on both volumes are _EQUAL_!";

        # debug
        echo "--- Creating New Latest snap on Original Replica... ---";

        # create snap
        zfs snapshot ${zfsVolOriginalFullName}@auto-`date +%Y%m%d-%H%M%S`;

        # get names of the latest new snap and snap before the latest
        snapOriginalNewLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
                | awk 'NR==1 {print $0}'`;
        snapOriginalBeforeNewLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
                | awk 'NR==2 {print $0}'`;

        # debug
        echo "Original New Latest snap: ${snapOriginalNewLatestFullName}";
        echo "Original Before New Latest snap: ${snapOriginalBeforeNewLatestFullName}";

        # debug
        echo "--- Making replication... ---";

        # make a replication
        zfs send -Pev -i ${snapOriginalBeforeNewLatestFullName} ${snapOriginalNewLatestFullName} | zfs recv -F ${zfsVolReplicaFullName};

        # debug
        echo "--- Destroying old replicas... ---";

        # destroy old snaps, leave only the newest snaps at the both Volumes - original and replica
        zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
                | awk -v i=${zfsSnapsNewestQtyToLeave} 'FNR>i {print $0}' | xargs -n 1 zfs destroy;
        zfs list -H -t snapshot -o name -S creation -r ${zfsVolReplicaFullName} \
                | awk -v i=${zfsSnapsNewestQtyToLeave} 'FNR>i {print $0}' | xargs -n 1 zfs destroy;

    # if Qty of snaps at original volume and replica volume are NOT equal
    else
        # debug
        echo "--- Latest snap names on both volumes are _NOT EQUAL_! It's necessary to remove all snaps on Replica Volume! ---";

        # if there are some snaps on Replica Volume
        if [ ${snapsReplicaQty} -gt 0 ]; then
            # debug
            echo "--- Destroying all snaps on Replica Volume... ---";

            # destroy all snaps at replica volume
            zfs destroy ${zfsVolReplicaFullName}@%;
        fi

        # debug
        echo "--- Creating New Latest snap on Original Replica... ---";

        # create snap at original Volume
        zfs snapshot ${zfsVolOriginalFullName}@auto-`date +%Y%m%d-%H%M%S`;

        # get the latest snap on Original Volume
        snapOriginalNewLatestFullName=`zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
                | awk 'NR==1 {print $0}'`;

        # debug
        echo "Original New Latest snap: ${snapOriginalNewLatestFullName}";

        # debug
        echo "--- Making replication... ---";

        # make a replication
        zfs send -Pev -R ${snapOriginalNewLatestFullName} | zfs recv -F ${zfsVolReplicaFullName};

        # debug
        echo "-- Destroying old replicas... ---";

        # destroy old snaps, leave only some newest snaps at the both Volumes - original and replica
        zfs list -H -t snapshot -o name -S creation -r ${zfsVolOriginalFullName} \
                | awk -v i=${zfsSnapsNewestQtyToLeave} 'FNR>i {print $0}' | xargs -n 1 zfs destroy;
        zfs list -H -t snapshot -o name -S creation -r ${zfsVolReplicaFullName} \
                | awk -v i=${zfsSnapsNewestQtyToLeave} 'FNR>i {print $0}' | xargs -n 1 zfs destroy;
    fi
fi
