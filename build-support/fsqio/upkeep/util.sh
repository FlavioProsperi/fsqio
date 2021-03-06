#!/bin/bash
# Copyright 2016 Foursquare Labs Inc. All Rights Reserved.

# Library of functions that are useful across the upkeep pipeline.

set -ea
set -o pipefail

function print_help() {
  echo ""
  echo -e "upkeep:\n\tManage dependencies and the development environment."
  echo ""
  echo "Usage:"
  echo -e "\tCommands that accept a [<tasks>...] list expect it as a space-delimited string.\n"
  echo -e "General"
  echo -e " - ./upkeep\n\tRun all required tasks, possibly a noop."
  echo -e " - ./upkeep [<options>] tasks\n\tList available tasks."
  echo -e " - ./upkeep [<options>] <tasks>...\n\tRun tasks, required or not. (can add downstream tasks, see Options)."
  echo -e " - ./upkeep run SCRIPT [<args>...] \n\tExecute './\$SCRIPT \${args[@]}' with full access to upkeep env."
  echo -e "  \tSCRIPT can be <upkeep_root>/scripts/\${SCRIPT}.sh or a file path relative to the build root."
  echo ""
  echo -e "Options"
  echo -e " --help\n\t Print this message."
  echo -e " --[no]-downstream\n\t When enabled, upkeep will operate over a task and all of its downstream tasks."
  echo -e " --all\n\t Operates over all tasks. This implies downstream tasks ordering."
  echo -e " --[no]-skip-tasks\n\t When enabled, upkeep will seed environment and route args, but will not run tasks."
  echo ""
  echo -e "Advanced"
  echo -e " - ./upkeep check [<tasks>...]\n\tCheck given tasks and run if required. Will not follow downstream tasks."
  echo -e " - ./upkeep [<options>] force [<tasks>...]\n\tForce all users to run specified tasks upon consumption."
  echo -e "\t(Can include forcing specified 'downstream tasks', i.e. task dependencies)."
  echo -e " - ./upkeep task-list\n\tReturn space-delimited list of available tasks (suitable for tests/scripting)."
  echo ""
}

function join_array() {
  # usage: `join_array ${SEP} ${ARR}`
  #    e.g. `ARR=( 1 2 aa. b ) && join_by , ${ARR}` will print "1,2, aa., b"
  sep="${1}" && shift
  echo -n ${1}
  if [[ $# -gt 1 ]]; then
    shift
    printf " ${sep} %s " $*
  fi
}

function print_all_tasks() {
  echo -e "Upkeep Tasks"
  # Separator for downstream tasks, if they are requested.
  sep=" -> "
  echo ""
  echo -n "Available tasks"
    if [[ "${DOWNSTREAM_TASKS}" == "true" ]]; then
      echo -n " ( \$task${sep}downstream )"
    fi
  echo -en ":\n"
  task_list=$(all_task_names)
  for i in ${task_list[@]}; do
    # Respects '--no-downstream' or '--downstream'. If enabled, display all downstream tasks separated by ${sep}.
    if [[ "${DOWNSTREAM_TASKS}" == "true" ]]; then
      task_chain=( $(get_task_and_downstream "${i}") )
    else
      task_chain=( "${i}" )
    fi
    echo -e "\t$(join_array ${sep} ${task_chain[@]} )" || exit_with_failure "Error in upkeep, perhaps b/c of printf."
  done
  echo -e "\nOptions:"
  echo -e "\t- Enter './upkeep tasks --downstream' to list downstream tasks."
  echo -e "\t- Further upkeep usage can be seen with \`./upkeep --help\`\n"
}

function get_task_and_downstream() {
  # Prints a space de-limited list of starting with the passed task and followed by all downstream tasks, if any exist.
  # usage: get_task_and_downstream ${task_name}
  #     e.g. `get_task_and_downstream your_task` for your_task.sh.
  # Respects DOWNSTREAM_TASKS if "true".
  if [[ "${DOWNSTREAM_TASKS}" == "true" ]]; then
    downs=$(find_upkeep_file "downstream-tasks" "${1}") && IFS=$'\n' read -d '' -r -a tasks < "${downs}"
  fi
  tasks=( "${1}" "${tasks[@]}" )
  echo "${tasks[@]}"
}

function all_matched_files() {
  # Glob files under upkeep subfolder. If no files match, returns empty string.
  # usage: `all_matched_files $action_type $regex`
  echo $(find ${UPKEEPROOT}/*/upkeep/${1}/${2} -type f 2> /dev/null)
}

function all_task_names() {
  # Defaults to returning the task_name of all available tasks.
  # usage: `get_task_names $regex`
  glob=${1:-"*"}
  task_files=( $(all_matched_files "tasks" "${glob}") )

  # I wish this was better - having to make it work on multiple shells killed any hope of it reading clearly.
  # TODO(mateo): This still sorts the fsqio after the foursquare. Strip, and then sort.
  for i in ${task_files[@]}; do
    tasks=(${tasks[@]} $(echo ${i##*/} | cut -d. -f1))
  done
  echo ${tasks[@]} | sort -u
}

function find_upkeep_file() {
  # Ensure there is only one configured match for a given task.
  # usage: find_upkeep_file [tasks|required|current|downstream-tasks|etc] task_name'

  upkeep_action="${1}"
  file_name="${2}"
  found_matches=( $(all_matched_files "${upkeep_action}" "${file_name}") )

  case "${#found_matches[@]}" in
    0 )
      # TODO(mateo) Improve the "magic" path knowledge here. Should be extrapolated so it doesn't get stale.
      exit_with_failure "No match registered under ${UPKEEPROOT}/<foo>/upkeep/${upkeep_action}: ${file_name}"
      ;;
    1 )
      echo "${found_matches[@]}"
      ;;
    * )
      exit_with_failure "Exactly one upkeep file may be registered under a given name!"
      ;;
  esac
}

function tempdir {
  mktemp -d "$1"/upkeep.XXXXXX
}

function get_current_path() {
  req_dir=$(dirname "${1}")
  current_dir="${req_dir}/../current"
  echo "${current_dir}/${2}"
}

function colorized_error() {
  echo -ne "[31;50m${1}[0m"
}

function colorized_warn() {
  echo -ne "[32;50m${1}[0m"
}

function print_output() {
  exec echo "$@"
}

function exit_with_failure() {
  colorized_error "\nUPKEEP FAILURE! "
  # TODO(mateo): May be better to allow the task to decide about colored output here.
  for i in "$@"; do
    colorized_error "${i}\n"
  done
  exit 1
}
