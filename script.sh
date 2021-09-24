#!/bin/bash

# arguments array
PARAMS=("$@")

# last argument is video url
URL=${PARAMS[-1]}
REMOVE_ASSETS=1

# keep assets if -k is passed
if [[ ${#PARAMS[@]} > 1 && "$@" =~ "-k" ]]; then
	REMOVE_ASSETS=0
fi

# get line with info json file name from stdout
INFODATA=`youtube-dl --write-info-json --skip-download --restrict-filenames -o '%(title)s.%(ext)s' $URL | tee /dev/tty | grep ".info.json"`

# get info json file name from INFODATA
INFOFILE="${INFODATA##* }"

# read info json file into variable
INFOJSON=`cat $INFOFILE`

ID=`echo $INFOJSON | jq -r '.id'`

_FILENAME=`echo $INFOJSON | jq '._filename' | sed 's/\"//g'`
FILENAME="${_FILENAME%.*}"

rm -rf "assets-$ID"
mkdir "assets-$ID"
mv $INFOFILE "assets-$ID"
cd "assets-$ID"

function showvideoonlyformats() {
	echo "=== Available Video Formats ==="
	echo $INFOJSON | jq -r '.formats[] | select(.acodec == "none") | [.format_id, (.filesize | tostring), .ext+", "+(.tbr | tostring)+"k, "+.format+", "+.container+", "+.vcodec+" @ "+(.vbr | tostring)+"k, "+(.fps | tostring)+" fps"] | @tsv' |
	  while IFS=$'\t' read -r formatid filesize format; do
	  	fsize=`numfmt --to=iec-i --suffix=B --padding=-7 $filesize`
	    echo -e "format code: $formatid\t\tSize: $fsize\tDetails: $format"
	  done
}

function showaudioonlyformats() {
	echo "=== Available Audio Formats ==="
	echo $INFOJSON | jq -r '.formats[] | select(.vcodec == "none") | [.format_id, (.filesize | tostring), .ext+", "+(.tbr | tostring)+"k, "+.format+", "+.container+", "+.acodec+" @ "+(.abr | tostring)+"k ("+(.asr | tostring)+"Hz)"] | @tsv' |
	  while IFS=$'\t' read -r formatid filesize format; do
	  	fsize=`numfmt --to=iec-i --suffix=B --padding=-7 $filesize`
	    echo -e "format code: $formatid\t\tSize: $fsize\tDetails: $format"
	  done
}

function showaudiovideoformats() {
	echo "=== Available Formats ==="
	echo $INFOJSON | jq -r '.formats[] | select(.vcodec != "none" and .acodec != "none") | [.format_id, (.filesize | tostring), .ext+", "+(.tbr | tostring)+"k, "+.format+", "+.vcodec+", "+.acodec+" ("+(.asr | tostring)+"Hz)"] | @tsv' |
	  while IFS=$'\t' read -r formatid filesize format; do
	  	re='^[0-9]+$'
	  	if [[ $filesize =~ $re ]] ; then
	  		fsize=`numfmt --to=iec-i --suffix=B --padding=-7 $filesize`
	  	else
	  		fsize='       '
	  	fi
	    echo -e "format code: $formatid\t\tSize: $fsize\tDetails: $format"
	  done
}

AFORMATS=`echo $INFOJSON | jq -r '.formats[] | select(.vcodec == "none") | .format_id'`
VFORMATS=`echo $INFOJSON | jq -r '.formats[] | select(.acodec == "none") | .format_id'`
AVFORMATS=`echo $INFOJSON | jq -r '.formats[] | select(.vcodec != "none" and .acodec != "none") | .format_id'`

AVCODESARRAY=(`echo $AVFORMATS`)
ACODESARRAY=(`echo $AFORMATS`)
VCODESARRAY=(`echo $VFORMATS`)

# Download combined format if video only and audio only formats are not available
if [[ ${#VCODESARRAY[@]} > 0 && ${#ACODESARRAY[@]} > 0 ]]; then
	read -p "Download video and audio combined? (y/n) [y]: " SINGLEFILE
fi

case "$SINGLEFILE" in
  y | n)
    ;;
  *)
    SINGLEFILE=y;;
esac

function downloadmulti() {
	
	CHAPTERS=`echo $INFOJSON | jq '.chapters'`

	NEWFILE_NAME="${FILENAME}_${ID}_${VIDFORMAT}_${AUDFORMAT}_WCH.mkv"

	# Download video and audio formats separately

	youtube-dl -f "${VIDFORMAT},${AUDFORMAT}" $1 -o "%(title)s_%(format_id)s.%(ext)s" --restrict-filenames

	if [[ $CHAPTERS == null ]]; then
		echo "No chapters found!"
		ffmpeg -i *"_${VIDFORMAT}."* -i *"_${AUDFORMAT}."* -c copy $NEWFILE_NAME
	else
		# Extract metadata from json using jq
	
		echo $INFOJSON | jq '";FFMETADATA1", ("title="+.title), ("artist="+.uploader), ""' > "$FILENAME.meta"
		echo $CHAPTERS | jq '.[] | "[CHAPTER]", "TIMEBASE=1/1",  "START="+(.start_time | tostring), "END="+(.end_time | tostring), "title="+.title, ""' >> "$FILENAME.meta"
	
		# Remove " from generated metadata file using sed
	
		sed -i 's/\"//g' "$FILENAME.meta" 
	
		# Attaching metadata to video using ffmpeg
	
		ffmpeg -i *"_${VIDFORMAT}."* -i *"_${AUDFORMAT}."* -i "${FILENAME}.meta" -map_metadata 1 -c copy $NEWFILE_NAME
	fi

	mv $NEWFILE_NAME ../
}

function downloadsingle() {
	
	youtube-dl --restrict-filenames -o '%(title)s_%(format_id)s.%(ext)s' -f $SINGLEFORMAT $1

	CHAPTERS=`echo $INFOJSON | jq '.chapters'`

	if [[ $CHAPTERS == null ]]; then
		echo "No chapters found!"
		mv *"${SINGLEFORMAT}."* ../
	else
		_FILENAME=`echo $INFOJSON | jq '._filename' | sed 's/\"//g'`
		FILENAME="${_FILENAME%.*}"

		NEWFILE_NAME="${FILENAME}_${ID}_${SINGLEFORMAT}_WCH.mkv"

		# Extract metadata from json using jq

		echo $INFOJSON | jq '";FFMETADATA1", ("title="+.title), ("artist="+.uploader), ""' > "$FILENAME.meta"
		echo $CHAPTERS | jq '.[] | "[CHAPTER]", "TIMEBASE=1/1",  "START="+(.start_time | tostring), "END="+(.end_time | tostring), "title="+.title, ""' >> "$FILENAME.meta"

		# Remove " from generated metadata file using sed

		sed -i 's/\"//g' "$FILENAME.meta" 

		# Attaching metadata to video using ffmpeg

		ffmpeg -i *"${SINGLEFORMAT}."* -i "${FILENAME}.meta" -map_metadata 1 -c copy $NEWFILE_NAME

		mv $NEWFILE_NAME ../
	fi
}

if [[ $SINGLEFILE == 'y' ]]; then
	showaudiovideoformats
	# Make sure format code is available
	while [[ -z $SINGLEFORMAT || ! " ${AVCODESARRAY[*]} " =~ "${SINGLEFORMAT}" ]]; do
		read -p "Choose combined video and audio format code : " SINGLEFORMAT
	done
	downloadsingle $URL
else
	showvideoonlyformats
	while [[ -z $VIDFORMAT || ! " ${VCODESARRAY[*]} " =~ "${VIDFORMAT}" ]]; do
		read -p "Choose video format code : " VIDFORMAT
	done
	showaudioonlyformats
	while [[ -z $AUDFORMAT || ! " ${ACODESARRAY[*]} " =~ "${AUDFORMAT}" ]]; do
		read -p "Choose audio format code : " AUDFORMAT
	done
	downloadmulti $URL
fi

# Remove assets folder after download
if [[ $REMOVE_ASSETS == 1 ]]; then
	cd ..
	rm -rf "assets-$ID"
fi
