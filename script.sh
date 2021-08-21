#!/bin/sh

# Sanitize filename

FILENAME=`youtube-dl -e $1 | sed -e 's/[^A-Za-z0-9._-]/_/g'`

OUTPUTFILE="${FILENAME}_%(resolution)s.%(ext)s"
INFOFILE="${FILENAME}*.info.json"

# Download video

youtube-dl --write-info-json -f 'worst' $1 -o $OUTPUTFILE

# Extract metadata from json using jq

cat $INFOFILE | jq '";FFMETADATA1", ("title="+.title), ("artist="+.uploader), ""' > "$FILENAME.meta"
cat $INFOFILE | jq '.chapters[] | "[CHAPTER]", "TIMEBASE=1/1",  "START="+(.start_time | tostring), "END="+(.end_time | tostring), "title="+.title, ""' >> "$FILENAME.meta"

# Remove " from generated metadata file using sed

sed -i 's/\"//g' "$FILENAME.meta"

# Extract output file name from json file

OUTPUTFILE_NAME=`cat $INFOFILE | jq '._filename' | sed 's/\"//g'`

OUTPUTFILE_EXT="${OUTPUTFILE_NAME##*.}"
OUTPUTFILE_BASENAME="${OUTPUTFILE_NAME%.*}"

NEWFILE_NAME="${OUTPUTFILE_BASENAME}_with_chapters.${OUTPUTFILE_EXT}"

# Attaching metadata to video using ffmpeg

ffmpeg -i $OUTPUTFILE_NAME -i "$FILENAME.meta" -map_metadata 1 -codec copy $NEWFILE_NAME
