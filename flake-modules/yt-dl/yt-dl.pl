#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

# 1. Validate Input
my $url = shift @ARGV or die "Usage: $0 <url>\n";

# 2. Check Dependencies
for my $tool (qw(yt-dlp ffmpeg)) {
    system("command -v $tool >/dev/null 2>&1") == 0
        or die "Error: '$tool' is required but not installed/found in PATH.\n";
}

say "Initializing download and transcode workflow for DaVinci Resolve...";

# 3. Define the Post-Processing Command
#    We pass this string to yt-dlp's internal exec handler.
#    - dnxhd/dnxhr_sq: The visually lossless editing codec.
#    - pcm_s16le: The required audio format for Linux Resolve.
#    - {}: yt-dlp replaces this with the downloaded filename.
my $ffmpeg_post_process = 
    'ffmpeg -y -hide_banner -loglevel error ' .
    '-i {} ' .
    '-c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p ' .
    '-c:a pcm_s16le ' .
    '-f mov {}.mov ' .
    '&& rm {}';

# 4. Execute yt-dlp
#    Using a list prevents shell injection on the URL variable.
my @cmd = (
    'yt-dlp',
    '--format', 'bestvideo+bestaudio/best',
    '--cookies-from-browser', 'firefox',
    '--exec',   $ffmpeg_post_process,
    $url
);

# Run the command and check exit status
system(@cmd) == 0 
    or die "Process failed: yt-dlp exited with code " . ($? >> 8) . "\n";

say "Success. File converted to MOV (DNxHR/PCM).";

