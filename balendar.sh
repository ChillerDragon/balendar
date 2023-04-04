#!/bin/bash

DATA_DIR="$HOME/.config/crools/balendar"

BALENDAR_VERSION=v2

EVENT_SLUG_PATTERN='^[a-z_]+$'

# "types" and naming
#
# certian variable names are expected to hold
# certian format of values
#
# +---------------+--------------+-----------------------------------------------------------+
# | variable name | sample value | info                                                      |
# +---------------+--------------+-----------------------------------------------------------+
# | day           | 2023-04-20   | output of the `date '+%F'` command yyyy-dd-mm             |
# | year          | 2023         | output of the `date '+%Y' command yyyy                    |
# |               |              |                                                           |
# +---------------+--------------------------------------------------------------------------+

check_dep() {
	# usage: check_dep <dependency> <str in help page>
	# ex dependency: git
	# ex str in help page: clone
	# side effects: error and exit script
	local dep="$1"
	local str_in_help_page="$2"
	if [[ ! -x "$(command -v "$dep")" ]]
	then
		echo "Error: missing dependency '$dep'"
		exit 1
	fi
	[[ "$str_in_help_page" == "" ]] && return

	local help_txt
	help_txt="$($dep --help 2>&1;$dep --help 2>&1)"
	if ! echo "$help_txt" | grep -qF -- "$str_in_help_page"
	then
		echo "Error: missing '$str_in_help_page' in '$dep'"
		exit 1
	fi
}

check_dep zenity --calendar

if ((BASH_VERSINFO[0] < 5))
then
	echo "Sorry, you need at least bash-5.0 to run this script."
	exit 1
fi

get_next_seven_days() {
	# usage: get_next_seven_days
	# output: newline seperated days in 2023-04-04 format
	local day
	local i
	for((i=0;i<7;i++))
	do
		day="$(date '+%F' -d "today +$i days")"
		echo "$day"
	done
}

get_events_in_days() {
	# usage: get_events_in_days <profile> <days>
	# ex profile: default
	# ex day: 2023-04-04
	local profile="$1"
	shift
	local days
	readarray -t days <<< "$@"
	local day
	local day_dir
	local event_file
	local year
	year="$(date '+%Y')"
	for day in "${days[@]}"
	do
		day_dir="$DATA_DIR/$profile/data/$year/$day"
		[ -d "$day_dir" ] || continue

		for event_file in "$day_dir"/*.md
		do
			[[ -f "$event_file" ]] || continue

			echo "$event_file"
		done
	done
}

print_event_boilerplate() {
	# usage: print_event_boilerplate <event_slug> <title>
	# ex event_slug: steves_birthday
	# ex title: Steven's birthday
	local event_slug="$1"
	cat <<- EOF
	---
	version: $BALENDAR_VERSION
	short_slug: $event_slug
	state: pending
	---

	# $title

	event details here
	EOF
}

get_year_from_day() {
	# usage: get_year_from_day <day>
	# output: year
	local day="$1"

	# TODO: rewrite in pure bash
	echo "$day" | cut -d '-' -f1
}

create_event_boilerplate() {
	# usage: create_event_boilerplate <profile> <day> <event_slug> <title>
	# ex profile: default
	# ex day: 2023-04-04
	# ex event_slug: steves_birthday
	# ex title: Steven's birthday
	# output: event_file_path
	local profile="$1"
	local day="$2"
	local event_slug="$3"
	local event_file
	event_file="$(build_event_file_path "$profile" "$event_slug" "$day")"
	[[ -f "$event_file" ]] && return

	local day_dir
	day_dir="${event_file%/*}"
	mkdir -p "$day_dir" || exit 1
	print_event_boilerplate "$event_slug" "$title" > "$event_file"
	echo "$event_file"
}

pick_new_day_interactive() {
	# usage: pick_new_day_interactive
	# needs a interactive session
	# is asking for user input

	local d
	local m
	local y

	# TODO: use terminal fallback
	IFS='/' read -r d m y <<< "$(zenity --calendar)"
	echo "$y-$d-$m"
}

get_event_slug_interactive() {
	# usage: get_event_slug_interactive
	# needs a interactive session
	# is asking for user input
	# output: event_slug
	# stderr: user prompts
	local event_slug
	while [[ ! "$event_slug" =~ $EVENT_SLUG_PATTERN ]]
	do
		printf "event_slug (has to match %s): " "$EVENT_SLUG_PATTERN" 1>&2
		read -r event_slug
	done
	echo "$event_slug"
}

edit_file() {
	# usage: edit_file <filename>
	# needs a interactive session
	# is asking for user input
	local filename="$1"
	echo "[edit_file] editing file '$filename' ..."
	vim "$filename"
}

build_event_file_path() {
	# usage: build_event_file_path <profile> <event_slug> <day>
	# ex profile: default
	# ex event_slug: my_event
	# ex day: 2023-26-04
	local profile="$1"
	local event_slug="$2"
	local day="$3"
	local year
	local event_file
	year="$(get_year_from_day "$day")"
	local day_dir="$DATA_DIR/$profile/data/$year/$day"
	event_file="$day_dir/$event_slug.md"
	echo "$event_file"
}

title_to_event_slug() {
	# usage: title_to_event_slug <title>
	# ex title: Title (with spaces & other fancy letters)
	# output: title__with_spaces___other_fance_letters
	local title="$1"
	# TODO: use more pure bash here
	echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z_]/_/g'
}

get_title_interactive() {
	# usage: get_title_interactive
	# needs a interactive session
	# is asking for user input
	# output: title
	# stderr: user prompts
	local title
	while [[ "$title" == "" ]]
	do
		printf "event title: " 1>&2
		read -r title
	done
	echo "$title"
}

create_event_interactive() {
	# usage: create_event_interactive <profile>
	# ex profile: default
	# needs a interactive session
	# is asking for user input
	local day
	local profile=default # TODO: pick
	local event_slug
	local boilerplate_file
	local title

	while true
	do
		day="$(pick_new_day_interactive)"
		# event_slug="$(get_event_slug_interactive)"
		while true
		do
			title="$(get_title_interactive)"
			event_slug="$(title_to_event_slug "$title")"
			event_file="$(build_event_file_path "$profile" "$event_slug" "$day")"
			if [ -f "$event_file" ]
			then
				printf \
					"\nError: event already exists '%s'\n" \
					"$event_file" \
					1>&2
			else
				break
			fi
		done

		if [ -f "$event_file" ]
		then
			echo "Error: event already exists '$event_file'"
		else
			break
		fi
	done

	boilerplate_file="$(create_event_boilerplate "$profile" "$day" "$event_slug" "$title")"
	edit_file "$boilerplate_file"
}

test_develop() {
	test
}

parse_args() {
	local arg
	if [ "$#" == "0" ]
	then
		test_develop
		exit 0
	fi
	while true
	do
		[[ "$#" -gt 0 ]] || break

		arg="$1"
		shift

		if [ "$arg" == "create" ]
		then
			create_event_interactive
		elif [ "$arg" == "week" ]
		then
			get_events_in_days default "$(get_next_seven_days)"
		fi
	done
}

parse_args "$@"

