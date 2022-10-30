# mkv_repack
Tool used to repack .mkv files with only English audio and subtitle tracks. Based off a script I found written in Python 2.7 and didn't have the abilty to fix at the time. This has gotten a little out of hand.

Three available modes:

  Recon:

    Run through all files and find the ones that need to be processed and display stats and a count.

  Copy:

    Create a copy of the processed file in the same directory with (MKV_REPACK) appended to the end of the name.

  Replace:

    Backup the original file to a specified directory and then replace the file in the original location with the processed file.
    
Future Plans:
  - GUI for selecting video files to process.
  - Better handling of default audio tracks.
  - Support for classifications of subtitle tracks.

Recent Changes:
  - Storage of results in a usable format. Maybe JSON, just to know how the file was processed and reduced in size(data hoarder things).
  - Better handling of foreign films.
