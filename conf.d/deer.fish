# deer.fish - File navigator for fish shell
# Port of https://github.com/vifon/deer for fish shell

# TODO: search
# TODO: filter
# TODO: image preview

# Set default values
set -g DEER_HEIGHT 22
set -g DEER_SHOW_HIDDEN false
set -g DEER_PARENT_WIDTH 20
set -g DEER_CURRENT_WIDTH 24
set -g DEER_PREVIEW_WIDTH 60

# Define key bindings
set -g DEER_KEY_DOWN j
set -g DEER_KEY_UP k
set -g DEER_KEYS_PAGE_DOWN J
set -g DEER_KEYS_PAGE_UP K
set -g DEER_KEY_ENTER l
set -g DEER_KEY_LEAVE h
set -g DEER_KEY_QUIT q
set -g DEER_KEY_TOGGLE_HIDDEN H
set -g DEER_KEYS_APPEND_PATH a
set -g DEER_KEYS_APPEND_ABS_PATH A
set -g DEER_KEYS_INSERT_PATH i
set -g DEER_KEYS_INSERT_ABS_PATH I
set -g DEER_KEYS_CHDIR c
set -g DEER_KEYS_CHDIR_SELECTED C
set -g DEER_KEYS_RIFLE r
set -g DEER_KEYS_EDIT e
set -g DEER_KEYS_NEXT_PARENT ']'
set -g DEER_KEYS_PREV_PARENT '['
set -g DEER_KEYS_SEARCH /
set -g DEER_KEYS_FILTER f

# Taken from: https://github.com/dangh/relpath.fish
function relpath -a source target -d "Print target path with relative to the source path"
    set source (builtin realpath $source)
    set target (builtin realpath $target)
    set -l base
    while test -n "$source" -a -n "$target"
        echo $source | read -l -d / source_base source_rest
        echo $target | read -l -d / target_base target_rest
        test "$source_base" = "$target_base" || break
        set base "$base$source_base/"
        set source "$source_rest"
        set target "$target_rest"
    end
    if test -z "$source"
        set source "."
    else
        set source (string replace -a -r '[^/]+' '..' -- $source)
    end
    string replace -r '/$' '' -- "$source/$target"
end

function set_current_row
    set -l saved_tty (stty -g)
    stty raw -echo

    printf "\033[6n"
    set -l response ""
    while read -l -z -n 1 char
        set response $response$char
        test "$char" = "R"; and break
    end

    stty $saved_tty

    set response (string sub -s 3 -e -1 $response)
    set -g CURRENT_ROW (string split \; "$response")[1]
end

function deer_move -a movement
    # TODO: add optional flag to show hidden files
    set -l files (command ls -1 $DEER_DIRNAME)
    if test (count $files) -eq 0
        return
    end
    set -l index (contains -i -- $DEER_BASENAME $files)
    if test -z "$index"
        set index 1
    end

    if test (math "$index + $movement") -le 0
        set -g DEER_BASENAME $files[1]
    else if test (math "$index + $movement") -gt (count $files)
        set -g DEER_BASENAME $files[-1]
    else
        set -g DEER_BASENAME $files[(math "$index + $movement")]
    end
end

function deer_enter
    if test -d "$DEER_DIRNAME/$DEER_BASENAME"
        set -g DEER_DIRNAME "$DEER_DIRNAME/$DEER_BASENAME"
        # TODO: add optional flag to show hidden files
        set -g DEER_BASENAME (command ls -1 $DEER_DIRNAME | head -n 1)
    end
end

function deer_leave
    if test $DEER_DIRNAME != /
        set -g DEER_BASENAME (basename $DEER_DIRNAME)
        set -g DEER_DIRNAME (dirname $DEER_DIRNAME)
    end
end

function deer_get_preview
    set -l file "$DEER_DIRNAME/$DEER_BASENAME"
    if test -f $file
        if file $file | string match -q "*text*"
            head -n 10 $file
        else if file $file | string match -q "*image*"
            echo ""
        else
            echo "Binary file"
        end
    else if test -d $file
        ls -lh $file | head -n 10
    else
        echo "No preview available"
    end
end

function deer_relative_path
    set -l prompt_dir (relpath $DEER_PROMPTDIR "$DEER_DIRNAME/$DEER_BASENAME")
    # remove leading ./ from prompt_dir
    set prompt_dir (string replace -r '^\./' '' $prompt_dir)
    echo $prompt_dir
end

function deer_refresh
    set -l output_lines

    # Add current path at the top
    set prompt_dir (deer_relative_path)
    set prompt_len (string length $prompt_dir)
    set output_lines $output_lines (set_color green)"$prompt_dir"(set_color normal)

    # TODO: add optional flag to show hidden files
    set -l parent_files (command ls -1 (dirname $DEER_DIRNAME))
    # TODO: add optional flag to show hidden files
    set -l current_files (command ls -1 $DEER_DIRNAME)
    set -l preview (deer_get_preview)
    set -l preview_lines (string split \n -- $preview)

    set -l file_index (contains -i -- $DEER_BASENAME $current_files)
    if test -z "$file_index"
        set file_index 1
    end

    set -l parent_index (contains -i -- (basename $DEER_DIRNAME) $parent_files)
    if test -z "$parent_index"
        set parent_index 1
    end

    set -l trimmed_width (math $DEER_PARENT_WIDTH - 3)

    for i in (seq 1 $DEER_HEIGHT)
        set -l p $i
        if test $parent_index -gt 5
            set p (math "$parent_index - 5 + $i")
        end
        set -l parent_file (string pad -w $DEER_PARENT_WIDTH -r -- "")
        if test $p -le (count $parent_files)
            set -l prefix ""
            set -l is_current "$parent_files[$p]" = (basename $DEER_DIRNAME)
            set prefix (test $is_current; and echo "-> "; or echo "   ")

            set -l orig_len (string length -- $parent_files[$p])
            set -l trim_suffix ""
            set -l trim 0
            if test $orig_len -gt $trimmed_width
                set trim_suffix "…"
                set trim 1
            end
            set -l trimmed_name (string sub -l (math $trimmed_width - $trim) -- $parent_files[$p])

            if test -d (dirname $DEER_DIRNAME)"/$parent_files[$p]"
                set parent_file (string pad -w $DEER_PARENT_WIDTH -r -- "$prefix"(set_color blue)"$trimmed_name$trim_suffix"(set_color normal))
            else if test -x (dirname $DEER_DIRNAME)"/$parent_files[$p]"
                set parent_file (string pad -w $DEER_PARENT_WIDTH -r -- "$prefix"(set_color green)"$trimmed_name$trim_suffix"(set_color normal))
            else
                set parent_file (string pad -w $DEER_PARENT_WIDTH -r -- "$prefix$trimmed_name$trim_suffix")
            end
        end

        set -l f $i
        if test $file_index -gt 5
            set f (math "$file_index - 5 + $i")
        end
        set -l current_file (string pad -w $DEER_CURRENT_WIDTH -r -- "")
        if test $f -le (count $current_files)
            set -l is_selected "$current_files[$f]" = "$DEER_BASENAME"
            set -l prefix (test $is_selected; and echo "-> "; or echo "   ")

            set -l orig_len (string length -- $current_files[$f])
            set -l trim_suffix ""
            set -l trim 0
            if test $orig_len -gt $trimmed_width
                set trim_suffix "…"
                set trim 1
            end
            set -l trimmed_name (string sub -l (math $trimmed_width - $trim) -- $current_files[$f])

            if test -d "$DEER_DIRNAME/$current_files[$f]"
                set current_file (string pad -w $DEER_CURRENT_WIDTH -r -- "$prefix"(set_color blue)"$trimmed_name$trim_suffix"(set_color normal))
            else if test -x "$DEER_DIRNAME/$current_files[$f]"
                set current_file (string pad -w $DEER_CURRENT_WIDTH -r -- "$prefix"(set_color green)"$trimmed_name$trim_suffix"(set_color normal))
            else
                set current_file (string pad -w $DEER_CURRENT_WIDTH -r -- "$prefix$trimmed_name$trim_suffix")
            end
        else if test $f -eq 1 -a (count $current_files) -eq 0
            set current_file (string pad -w $DEER_CURRENT_WIDTH -r -- "<empty>")
        end

        set -l preview_line ""
        if test $i -le (count $preview_lines)
            set preview_line (string pad -w $DEER_PREVIEW_WIDTH -r -- $preview_lines[$i])
        end
        set preview_line (string sub -l $DEER_PREVIEW_WIDTH -- $preview_line)

        set output_lines $output_lines "$parent_file   $current_file   $preview_line"
    end

    # Restore cursor position
    tput rc

    # Clear the deer display area
    echo -en "\033[0J"

    # Print all lines at once
    printf "%s\n" $output_lines

    # Display image preview
    set -l file "$DEER_DIRNAME/$DEER_BASENAME"
    if file $file | string match -q "*image*"
        kitty +kitten icat --place $DEER_PREVIEW_WIDTH"x"$DEER_HEIGHT"@"(math $DEER_CURRENT_WIDTH + $DEER_PARENT_WIDTH + 8)"x"$CURRENT_ROW --clear --scale-up --transfer-mode=stream --stdin=no $file &
    end

    # Restore cursor position
    tput rc

    # Move cursor to the end of the line
    echo -en "\033["$prompt_len"C"
    #tput cuf $prompt_len

    commandline -f repaint
end

function deer_set_initial_directory
    set -l directory (string trim (commandline -t))
    # expand ~ to home directory
    set directory (eval echo $directory)
    if test -d "$directory"
        # convert to absolute path
        set deer_startdir (realpath $directory)
        # go up until we find a directory
        while test -n "$deer_startdir" -a ! -d "$deer_startdir"
            set deer_startdir (dirname $deer_startdir)
        end
    end

    set DEER_DIRNAME $deer_startdir
    test -z "$DEER_DIRNAME"; and set DEER_DIRNAME $PWD
end

function ensure_space -a needed_space
    set -l terminal_height (tput lines)

    set -l lines_to_scroll (math "$CURRENT_ROW + $needed_space - $terminal_height")

    if test $lines_to_scroll -gt 0
        tput sc
        for i in (seq $lines_to_scroll)
            tput ind  # Scroll up one line
        end
        tput rc
        tput cuu (math $lines_to_scroll + 1)
    end
end

function deer_launch
    set -g DEER_DIRNAME

    set_current_row

    ensure_space $DEER_HEIGHT

    # Save current cursor position
    tput sc

    #trap 'echo -en "\033[u"; echo -en "\033[0J"; commandline -f repaint'

    deer_set_initial_directory

    set -g DEER_PROMPTDIR $DEER_DIRNAME
    # TODO: add optional flag to show hidden files
    set -g DEER_BASENAME (command ls -1 $DEER_DIRNAME | head -n 1)

    deer_refresh

    while true
        read -l -z -n 1 -p "" key
        switch $key
            case $DEER_KEY_DOWN
                deer_move 1
                deer_refresh
            case $DEER_KEY_UP
                deer_move -1
                deer_refresh
            case $DEER_KEYS_PAGE_DOWN
                deer_move 5
                deer_refresh
            case $DEER_KEYS_PAGE_UP
                deer_move -5
                deer_refresh
            case $DEER_KEY_ENTER
                deer_enter
                deer_refresh
            case $DEER_KEY_LEAVE
                deer_leave
                deer_refresh
            case $DEER_KEY_TOGGLE_HIDDEN
                set -g DEER_SHOW_HIDDEN (not $DEER_SHOW_HIDDEN)
                deer_refresh
            case $DEER_KEY_QUIT
                break
            case $DEER_KEYS_APPEND_PATH
                commandline -i -- (string escape (deer_relative_path))
                break
            case $DEER_KEYS_APPEND_ABS_PATH
                commandline -t -- (string escape "$DEER_DIRNAME/$DEER_BASENAME")
                break
            case $DEER_KEYS_INSERT_PATH
                commandline -a -- (string escape (deer_relative_path))
                break
            case $DEER_KEYS_INSERT_ABS_PATH
                commandline -t -- (string escape "$DEER_DIRNAME/$DEER_BASENAME")
                set -l path_len (string length $DEER_DIRNAME/$DEER_BASENAME)
                # Move cursor to the beginning of the token
                #echo -en "\033["$path_len"D"
                tput cub $path_len
                break
            case $DEER_KEYS_CHDIR
                cd -- $DEER_DIRNAME
                break
            case $DEER_KEYS_CHDIR_SELECTED
                if test -d $DEER_DIRNAME/$DEER_BASENAME
                    cd -- $DEER_DIRNAME/$DEER_BASENAME
                    break
                else
                    deer_refresh
                end
            case $DEER_KEYS_RIFLE
                rifle $DEER_DIRNAME/$DEER_BASENAME
                break
            case '*'
                # Ignore other keys
        end
    end

    # Clear the display area
    echo -en "\033[0J"
    #tput ed

    commandline -f repaint
end

bind \ek deer_launch
