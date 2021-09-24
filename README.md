# Read Me
This is a shell script to attach chapters in to videos.

## Dependencies
- linux
- bash
- GNU coreutils
- youtube-dl
- [jq](https://stedolan.github.io/jq/)
- ffmpeg

## Usage
Make the file executable

    chmod u+x script.sh
Execute by passing video url as parameter

    ./script.sh url
Keep assets folder using -k argument

    ./script.sh -k url
