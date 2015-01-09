#!/bin/bash
#
# Backup mimicking Time Machine from Mac OS X using rsync



# --- Variables --- #

PROGRAM=$(basename $0)
OS=$(uname -s)
HOST=$(hostname)
DATE_FORMAT=$(date "+%Y-%m-%d-%H%M%S")
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%m)
RSYNC_BIN=$(which rsync)
RSYNC_OPTIONS="--archive --partial --progress --human-readable"

# Use absolute paths. Relative paths tend to break the hard linking advantage of rsync.
# Paths can include spaces as long as variable contents are double quoted
SOURCE="$1"
DESTINATION="$2"

# --- Functions --- #
die() {
    echo "$PROGRAM: $1" >&2
    exit ${2:-1}
}

help() {
  cat <<EOF
Usage: $PROGRAM "[SOURCE PATH]" "[DESTINATION PATH]"
EOF
  exit 0
}

create_dest() {
  # Create destination if it does not exist
  if [[ ! -d "$DESTINATION" ]] ; then
    mkdir -p "$DESTINATION"
  fi
}

backup() {
  # Make inital backup if Latest does not exist, otherwise only copy what has changed
  # and hard link to files that are the same
  if [[ ! -L "$DESTINATION"/Latest ]] ; then
    $RSYNC_BIN $RSYNC_OPTIONS \
                  --delete \
                  --exclude-from="$SOURCE/.rsync/exclude" \
                  "$SOURCE" "$DESTINATION"/$DATE_FORMAT
  else
    $RSYNC_BIN $RSYNC_OPTIONS \
                 --delete \
                 --delete-excluded \
                 --exclude-from="$SOURCE/.rsync/exclude" \
                 --link-dest="$DESTINATION"/Latest \
                 "$SOURCE" "$DESTINATION"/$DATE_FORMAT
  fi

}

relink() {
  # Remove symlink to previous Latest backup
  rm -f "$DESTINATION"/Latest

  # Create symlink to latest backup
  ln -s $DATE_FORMAT "$DESTINATION"/Latest
}

set_date_syntax() {
  # BSD date in OS X has a different syntax than GNU date in Linux
  if [[ $OS == "Darwin" || $OS == "FreeBSD" ]]; then

    # Return YYYY one year ago from today
    LAST_YEAR=$(date -v -1y "+%Y")

  elif [[ $OS == "Linux" ]]; then

    # Return YYYY one year ago from today
    LAST_YEAR=$(date -d "last year" "+%Y")

  fi
}

cleanup() {
  # Keep monthly backups for one year
  for (( month = 1 ; month < $CURRENT_MONTH ; month++ )); do
    # List latest backup from each month of current year
    # Use printf to pad the single digit months with a 0
    LATEST_BACKUP=$(find "$DESTINATION" -mindepth 1 -maxdepth 1 -name ${CURRENT_YEAR}-$(printf "%02d" $month)-* | sort | tail -n 1)
    find "$DESTINATION" -mindepth 1 -maxdepth 1 -name ${CURRENT_YEAR}-$(printf "%02d" $month)-* | grep -v "$LATEST_BACKUP" | xargs -I {} rm -rf {}
  done

  for (( month = $CURRENT_MONTH ; month <= 12 ; month++ )); do
    # List latest backup from each month of current year
    # Use printf to pad the single digit months with a 0
    LATEST_BACKUP=$(find "$DESTINATION" -mindepth 1 -maxdepth 1 -name ${LAST_YEAR}-$(printf "%02d" $month)-* | sort | tail -n 1)
    find "$DESTINATION" -mindepth 1 -maxdepth 1 -name ${LAST_YEAR}-$(printf "%02d" $month)-* | grep -v "$LATEST_BACKUP" | xargs -I {} rm -rf {}
  done


  # Remove backups older than one year
  for (( month = 1 ; month < $CURRENT_MONTH ; month++ )); do
    find "$DESTINATION" -mindepth 1 -maxdepth 1 -type d -name "$LAST_YEAR-$(printf "%02d" $month)-*" | xargs -I {} rm -rf {}
  done

  find "$DESTINATION" -mindepth 1 -maxdepth 1 -type d ! -name "$CURRENT_YEAR-*" | grep -v "$LAST_YEAR-*" | xargs -I {} rm -rf {}
}


# --- Main Program --- #

case $1 in
  --help|-h )
    help
    ;;
esac

if [[ $1 == '' ]]; then
  die "Source is not defined"
fi

if [[ $2 == '' ]]; then
  die "Target destination is not defined"
fi

create_dest
backup
relink

# Remove old backups
(
  set_date_syntax
  cleanup
)
