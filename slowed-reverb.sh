#!/bin/bash

show_help() {
    echo "Usage: $0 --audio-input (path_to_your_music_file) --cover-input (path_to_your_cover_file) [--output/-o (optional)]"
  echo "Options:"
  echo "  --audio-input, -a: Specify the input audio file."
  echo "  --cover-input, -c: Specify the input cover file (GIF, video, or image)."
  echo "  --output, -o: Specify the output file. (optional)"
  echo "  --help, -h: Show this help message."
  exit 1
}

# Init vars
audio_input=""
cover_input=""
output_file=""

# Parse args
while getopts ":a:c:o:h" opt; do
    case $opt in
        a) audio_input=$OPTARG ;;
        c) cover_input=$OPTARG ;;
        o) output_file=$OPTARG ;;
        h) show_help ;;
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            show_help ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help ;;
    esac
done

if [ -z "$audio_input" ] || [ -z "$cover_input" ]; then
    echo "Error: Missing required arguments." >&2
    show_help
fi

audio_ext="${audio_input##*.}"

if [ "$audio_ext" != "mp3" ]; then
    echo "Info: Converting audio file to mp3"
    ffmpeg -v 5 -y -i $audio_input -acodec libmp3lame -ac 2 -ab 192k ${audio_input%.*}.mp3
fi

# Output file names
music_sr_file="${audio_input%.*}_sr.mp3"
cover_bw_file="${cover_input%.*}_bw.jpg"
if [ -z "$output_file" ]; then
    output_file="${audio_input%.*}_out.mp4"
fi

if [ ! -f "$audio_input" ]; then
    echo "Error: Input audio file '$audio_input' does not exist." >&2
    exit 1
fi

if [[ "$cover_input" == *.gif ]]; then
    convert "$cover_input" -coalesce -colorspace GRAY "$cover_bw_file"
elif [[ "$cover_input" == *.jpg ]] || [[ "$cover_input" == *.jpeg ]] || [[ "$cover_input" == *.png ]]; then
    convert "$cover_input" -colorspace GRAY "$cover_bw_file"
elif [[ "$cover_input" == *.mp4 ]] || [[ "$cover_input" == *.mov ]] || [[ "$cover_input" == *.avi ]]; then
    ffmpeg -y -i "$cover_input" -vf "select=eq(n\,0)" -q:v 3 "$cover_bw_file"
else
    echo "Error: Invalid cover file format." >&2
    exit 1
fi

# TODO: Add option to enable highpass filter to prevent distortion
sox "$audio_input" "$music_sr_file" reverb 50 50 100 100 0.5 0.75 speed 0.85

if [[ "$cover_input" == *.mp4 ]] || [[ "$cover_input" == *.mov ]] || [[ "$cover_input" == *.avi ]]; then
    # Mute the video
    ffmpeg -y -i "$cover_input" -c copy -an muted_cover.mp4
  
    ffmpeg -y -i "$music_sr_file" -i muted_cover.mp4 -c:v copy -c:a aac -b:a 320k -pix_fmt yuv420p "$output_file"
    rm muted_cover.mp4
else
    duration=$(ffprobe -i "$music_sr_file" -show_entries format=duration -v quiet -of csv="p=0")
    ffmpeg -y -loop 1 -i "$cover_bw_file" -i "$music_sr_file" -t "$duration" -c:v libx264 -tune stillimage -c:a aac -b:a 320k -pix_fmt yuv420p "$output_file"
fi

# Delete temp files
# TODO: add option to keep temp files
# rm "$music_sr_file" "$cover_bw_file"
