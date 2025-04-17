#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Overwrite disk with random data & spoof BitLocker encryption header
#
# Usage: sudo fake-bitlocker.sh /dev/sdX [passes [label]]
#
#   /dev/sdX  Target drive to overwrite (e.g., /dev/sdb); REQUIRED
#   passes    Number of overwrite passes with random data; default: 1, can be 0
#   label     Label for the outer GPT partition; default: "Basic data partition"
#
# Note: If you want to set a custom partition label, you must also specify
# overwrite passes, as they are positional arguments. If you have already wiped
# the drive by writing random data to it, you can skip this phase with 0.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM

# Check for requirements. Print all unmet requirements at once.

required_command() {
  if ! command -v "$1" &> /dev/null; then
    if [ -z "${2+x}" ]; then
      echo "This script requires '$1'." >&2
    else
      echo "This script requires '$1' $2." >&2
    fi
    ((UNMET=UNMET+1))
  fi
}

UNMET=0
required_command "dd" "(GNU) for overwriting the drive and writing signatures"
required_command "sgdisk" "for writing the GPT partition table and partition label"
required_command "printf" "for injecting the fake BitLocker signature"
required_command "xxd" "for reading embedded fake header in hex"
required_command "date" "for detecting dd failure type"
required_command "tr"

if [ "$UNMET" -gt 0 ]; then
  echo
  echo "Please install the missing dependencies and try again."
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires sudo privileges for disk operations."
  exit 1
fi

# Parse configuration

DRIVE="$1"
OVERWRITE_PASSES="${2:-1}"
PARTITION_LABEL="${3:-Basic data partition}"

if [[ -z "$DRIVE" ]]; then
  echo "Error: No target drive specified." >&2
  echo
  echo -e "$USAGE" >&2
  exit 1
fi

if [[ ! -b "$DRIVE" ]]; then
  echo "Error: '$DRIVE' is not a valid block device." >&2
  exit 1
fi

# Confirmation

echo "==> WARNING: This will erase and modify ALL data on $DRIVE!"
echo "    Overwrite passes: $OVERWRITE_PASSES"
echo "    Partition label:  \"$PARTITION_LABEL\""
read -rp "Are you absolutely sure you want to continue? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# Step 1: Overwrite Drive

if [[ "$OVERWRITE_PASSES" -gt 0 ]]; then
  for ((i=1; i<=OVERWRITE_PASSES; i++)); do
    echo "==> Overwriting pass $i/$OVERWRITE_PASSES..."
    start_time=$(date +%s)
    # Note: 'status=progress' requires GNU dd
    dd if=/dev/urandom of="$DRIVE" bs=4M status=progress
    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    if [[ $elapsed_time -lt 20 ]]; then
      echo "Error: dd exited way too quickly for a successful overwrite" >&2
      exit 1
    fi
  done
else
  echo "==> Skipping overwrite as requested (0 passes)."
fi

# Step 2: Create GPT Partition with fake Microsoft style partition GUID

echo "==> Zeroing the beginning of the disk before partitioning."
dd if=/dev/zero of="$DRIVE" bs=512 count=2050 conv=notrunc status=progress

if command -v wipefs &> /dev/null; then
  echo "==> wipefs found; wiping possible existing partitions."
  wipefs -a "$DRIVE"
else
  echo "==> (optional) wipefs not found; letting sgdisk do its best later."
fi

generate_uuid_v4() {
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid && return 0
  fi

  # Fallback using xxd & bash string manipulation
  local raw
  raw=$(xxd -l 16 -p /dev/urandom | tr -d '\n')

  # Insert version (4) and variant (a/b/8/9)
  local uuid="${raw:0:8}-${raw:8:4}-4${raw:13:3}-a${raw:17:3}-${raw:20:12}"
  echo "$uuid"
}

create_partition() {
  sgdisk --zap-all \
    --clear \
    --new=1:0:0 \
    --typecode=1:0700 \
    --change-name=1:"$PARTITION_LABEL" \
    --partition-guid=1:"$(generate_uuid_v4)" \
    "$DRIVE"
}

echo "==> Creating GPT and partition table on $DRIVE..."
create_partition || {
  # Especially without the optional wipefs, the first try may fail
  echo "==> Error during partitioning; trying again!" >&2
  create_partition || {
    echo "==> Error: permanent error during partitioning" >&2
      exit 1
    }
  }

echo "==> Ensuring backup GPT header on $DRIVE..."
sgdisk --move-second-header "$DRIVE"

echo "==> Final GPT headers on $DRIVE:"
sgdisk --verify "$DRIVE"

# Step 3: Inject fake BitLocker NTFS boot sector

read -r -d '' fake_sector << EOM
eb58902d4656452d46532d00020800000000000000f800003f00ff0000080000
00000000e01f0000000000000000000001000600000000000000000000000000
800029000000004e4f204e414d4520202020464154333220202033c98ed1bcf4
7b8ec18ed9bd007ca0fb7db47d8bf0ac9840740c48740eb40ebb0700cd10ebef
a0fd7debe6cd16cd190000000000000000000000000000000000000000000000
3bd66749292ed84a8399f6a339e3d0010000f004000000000000f04400000000
0000f08400000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0d0a52656d6f7665206469736b73206f72206f74686572206d656469612eff0d
0a4469736b206572726f72ff0d0a507265737320616e79206b657920746f2072
6573746172740d0a000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000007878787878787878
7878787878787878787878787878787878787878787878787878787878787878
7878787878787878787878787878787878787878787878787878787878787878
7878787878787878ffffffffffffffffffffffffffffffffffffff001f2c55aa
EOM

echo "==> Writing fake BitLocker NTFS boot sector to $DRIVE..."
echo "$fake_sector" \
  | xxd -r -p \
  | dd of="$DRIVE" bs=512 seek=2048 conv=notrunc status=progress || {
    echo "==> Error writing the fake NTFS boot sector" >&2
    exit 1
  }

echo "==> Done! $DRIVE now appears like a BitLocker-encrypted disk (fake)."
