# mkv_repack
Tool used to repack .mkv files with only English audio and subtitle tracks.

Three available modes:

  Recon:

    Run through all files and find the ones that need to be processed and display stats and a count.

  Copy:

    Create a copy of the processed file in the same directory with (MKV_REPACK) appended to the end of the name.

  Replace:

    Backup the original file to a specified directory and then replace the file in the original location with the processed file.
    
Future Plans:
  - Storage of results in a usable format. Maybe JSON, just to know how the file was processed and reduced in size(data hoarder things).
  - GUI for selecting video files to process.
  - Better handling of foreign films.
  - Better handling of default audio tracks.
  - Support for classifications of subtitle tracks.
