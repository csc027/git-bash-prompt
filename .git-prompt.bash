# Usage:
#     In .bashrc do the following:
#         . bash-prompt-git.bash
#         PS1="\u@\h:\w\$(git_bash_prompt)\$ "
#                      ^^^^^^^^^^^^^^^^^^^^^
#     NOTE: The backslash before the $ is required.

# You can set these in .bashrc any time after sourcing this file to control
# the display of the prompt.
GIT_ADDED_INDICATOR="+"
GIT_DELETED_INDICATOR="-"
GIT_MODIFIED_INDICATOR="~"
GIT_UNCOMMITTED_INDICATOR="~"
GIT_UNSTAGED_INDICATOR="!"
GIT_CLEAN_INDICATOR="≡"
GIT_AHEAD_INDICATOR="↑"
GIT_BEHIND_INDICATOR="↓"
if [ "${color_prompt}" == "yes" ]; then
	GIT_AHEAD_BEHIND_COLOR="\033[0;93m"
	GIT_AHEAD_COLOR="\033[0;92m"
	GIT_BEHIND_COLOR="\033[0;31m"
	GIT_CHERRY_PICK_COLOR="\033[0;93m"
	GIT_CLEAN_STATUS_COLOR="\033[0;96m"
	GIT_CONFLICT_COLOR="\033[0;93m"
	GIT_DELIMITER_COLOR="\033[0;93m"
	GIT_ERROR_COLOR="\033[0;31m"
	GIT_GITDIR_COLOR="\033[0;93m"
	GIT_REBASE_COLOR="\033[0;93m"
	GIT_RESET_COLOR="\033[0m"
	GIT_STAGED_COLOR="\033[0;32m"
	GIT_UNCOMMITTED_COLOR="\033[0;96m"
	GIT_UNSTAGED_COLOR="\033[0;31m"
fi

# Helper function to read the first line of a file into a variable.
# __git_eread requires 2 arguments, the file path and the name of the
# variable, in that order.
__git_eread () {
	test -r "$1" && IFS=$'\r\n' read "$2" <"$1"
}

# see if a cherry-pick or revert is in progress, if the user has committed a
# conflict resolution with 'git commit' in the middle of a sequence of picks or
# reverts then CHERRY_PICK_HEAD/REVERT_HEAD will not exist so we have to read
# the todo file.
__git_cherrypick_status () {
	local todo
	if [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
		rebase_state="${GIT_DELIMITER_COLOR}|${GIT_CHERRY_PICK_COLOR}CHERRY-PICKING"
		return 0;
	elif [ -f "$gitdir/REVERT_HEAD" ]; then
		rebase_state="${GIT_DELIMITER_COLOR}|${GIT_CHERRY_PICK_COLOR}REVERTING"
		return 0;
	elif __git_eread "$gitdir/sequencer/todo" todo; then
		case "$todo" in
		p[\ \	]|pick[\ \	]*)
			rebase_state="${GIT_DELIMITER_COLOR}|${GIT_CHERRY_PICK_COLOR}CHERRY-PICKING"
			return 0
		;;
		revert[\ \	]*)
			rebase_state="${GIT_DELIMITER_COLOR}|${GIT_CHERRY_PICK_COLOR}REVERTING"
			return 0
		;;
		esac
	fi
	return 1
}

# see if the repo has a conflict.
__git_conflict_status() {
	if [[ $(git ls-files --unmerged 2>/dev/null) ]]; then
		conflict_state="${GIT_DELIMITER_COLOR}|${GIT_CONFLICT_COLOR}CONFLICT"
	fi
}

__git_gitdir_status () {
	if [ "true" = "${bare_repo}" ]; then
		bare_state="${GIT_GITDIR_COLOR}BARE:"
	else
		branch_ref="${GIT_GITDIR_COLOR}GIT_DIR!"
	fi

	gitdir_state="${bare_state}${branch_ref}"
}

# check to see if the repo is currently rebasing
__git_rebase_status () {
	local rebase_state=""
	local branch_ref=""
	local step=""
	local total=""
	if [ -d "$gitdir/rebase-merge" ]; then
		__git_eread "$gitdir/rebase-merge/head-name" b
		__git_eread "$gitdir/rebase-merge/msgnum" step
		__git_eread "$gitdir/rebase-merge/end" total
		rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}REBASE"
	else
		if [ -d "$gitdir/rebase-apply" ]; then
			__git_eread "$gitdir/rebase-apply/next" step
			__git_eread "$gitdir/rebase-apply/last" total
			if [ -f "$gitdir/rebase-apply/rebasing" ]; then
				__git_eread "$gitdir/rebase-apply/head-name" b
				rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}REBASE"
			elif [ -f "$gitdir/rebase-apply/applying" ]; then
				rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}AM"
			else
				rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}AM/REBASE"
			fi
		elif [ -f "$gitdir/MERGE_HEAD" ]; then
			rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}MERGING"
		elif __git_cherrypick_status; then
			:
		elif [ -f "$gitdir/BISECT_LOG" ]; then
			rebase_state="${GIT_DELIMITER_COLOR}|${GIT_REBASE_COLOR}BISECTING"
		fi

		if [ -n "$branch_ref" ]; then
			:
		elif [ -h "$gitdir/HEAD" ]; then
			# symlink symbolic ref
			branch_ref="$(git symbolic-ref HEAD 2>/dev/null)"
		else
			local head=""
			if ! __git_eread "$gitdir/HEAD" head; then
				return $exit
			fi
			# is it a symbolic ref?
			branch_ref="${head#ref: }"
			if [ "$head" = "$branch_ref" ]; then
				branch_ref="$(
				case "${GIT_PS1_DESCRIBE_STYLE-}" in
				(contains)
					git describe --contains HEAD ;;
				(branch)
					git describe --contains --all HEAD ;;
				(tag)
					git describe --tags HEAD ;;
				(describe)
					git describe HEAD ;;
				(* | default)
					git describe --tags --exact-match HEAD ;;
				esac 2>/dev/null)" ||

				branch_ref="$short_sha..."
				branch_ref="($branch_ref)"
			fi
		fi
	fi

	if [ -n "$step" ] && [ -n "$total" ]; then
		rebase_state="$rebase_state ${GIT_REBASE_COLOR}$step/$total"
	fi
}

__git_worktree_status () {
	local -i ahead=0 behind=0
	local -i index_added=0 index_deleted=0 index_modified=0 index_unmerged=0
	local -i worktree_added=0 worktree_deleted=0 worktree_modified=0 worktree_unmerged=0

	local branch="" error="" remote="" line

	while IFS= read -r line ; do
		if [[ "${line:0:2}" = "xx" ]]; then return 1; fi
		if [[ "${line:2:1}" != " " ]]; then error="unexpected git status output"; return 0; fi

		# https://git-scm.com/docs/git-status
		local x=${line:0:1}
		local y=${line:1:1}

		if [[ "${x}${y}" = "##" ]]; then
			# extract branch information
			branch=${line:3}
			remote="${branch#*...}"
			branch="${branch%%...*}"

			# extract commit ahead and behind counts
			if [[ $remote =~ .*\[.*ahead[[:blank:]]+([0-9]+).*\] ]]; then ahead=$((${BASH_REMATCH[1]})); fi
			if [[ $remote =~ .*\[.*behind[[:blank:]]+([0-9]+).*\] ]]; then behind=$((${BASH_REMATCH[1]})); fi
		else
			if [[ "${x}" = "A" ]]; then ((index_added++)); fi
			if [[ "${x}" = "D" ]]; then ((index_deleted++)); fi
			if [[ "${x}" = "M" ]] || [[ "${x}" = "R" ]] || [[ "${x}" = "C" ]]; then ((index_modified++)); fi
			if [[ "${x}" = "U" ]]; then ((index_unmerged++)); fi
			if [[ "${y}" = "A" ]] || [[ "${y}" = "?" ]]; then ((worktree_added++)); fi
			if [[ "${y}" = "D" ]]; then ((worktree_deleted++)); fi
			if [[ "${y}" = "M" ]]; then ((worktree_modified++)); fi
			if [[ "${y}" = "U" ]]; then ((worktree_unmerged++)); fi
		fi
	done < <(LC_ALL=C git status --porcelain --branch 2>/dev/null || echo -e "xx $?")

	local delimiter error_state index_state status_state working_tree_state working_state

	if [[ -n "${error}" ]]; then
		worktree_state="${GIT_ERROR_COLOR}${error}"
	elif [[ -n "${branch}" ]]; then
		if ((ahead == 0 && behind == 0)); then status_state="${GIT_CLEAN_STATUS_COLOR}${branch} ${GIT_CLEAN_INDICATOR}"
		elif ((ahead > 0 && behind > 0)); then status_state="${GIT_AHEAD_BEHIND_COLOR}${branch} ${GIT_AHEAD_INDICATOR}${ahead} ${GIT_BEHIND_INDICATOR}${behind}"
		elif ((ahead > 0)); then status_state="${GIT_AHEAD_COLOR}${branch} ${GIT_AHEAD_INDICATOR}${ahead}"
		elif ((behind > 0)); then status_state="${GIT_BEHIND_COLOR}${branch} ${GIT_BEHIND_INDICATOR}${behind}"
		fi

		if ((index_added > 0 || index_modified > 0 || index_deleted > 0)); then
			index_state=" ${GIT_STAGED_COLOR}${GIT_ADDED_INDICATOR}${index_added} ${GIT_MODIFIED_INDICATOR}${index_modified} ${GIT_DELETED_INDICATOR}${index_deleted}"
		fi
		if (( (index_added > 0 || index_modified > 0 || index_deleted > 0) && (worktree_added > 0 || worktree_modified > 0 || worktree_deleted > 0) )); then
			delimiter=" ${GIT_DELIMITER_COLOR}|"
		fi
		if ((worktree_added > 0 || worktree_modified > 0 || worktree_deleted > 0)); then
			working_tree_state=" ${GIT_UNSTAGED_COLOR}${GIT_ADDED_INDICATOR}${worktree_added} ${GIT_MODIFIED_INDICATOR}${worktree_modified} ${GIT_DELETED_INDICATOR}${worktree_deleted}"
		fi

		if ((worktree_added > 0 || worktree_modified > 0 || worktree_deleted > 0)); then
			working_state=" ${GIT_UNSTAGED_COLOR}${GIT_UNSTAGED_INDICATOR}"
		elif ((index_added > 0 || index_modified > 0 || index_deleted)); then
			working_state=" ${GIT_UNCOMMITTED_COLOR}${GIT_UNCOMMITTED_INDICATOR}"
		fi

		worktree_state="${status_state}${index_state}${delimiter}${working_tree_state}${working_state}"
	fi
}

git_bash_prompt () {
	# preserve exit status
	local exit=$?

	local repo_info="$(git rev-parse --git-dir --is-inside-git-dir --is-bare-repository --is-inside-work-tree --short HEAD 2>/dev/null)"
	local rev_parse_exit_code="$?"

	if [ -z "$repo_info" ]; then
		return $exit
	fi

	local short_sha=""
	if [ "$rev_parse_exit_code" = "0" ]; then
		short_sha="${repo_info##*$'\n'}"
		repo_info="${repo_info%$'\n'*}"
	fi

	local inside_worktree="${repo_info##*$'\n'}"
	repo_info="${repo_info%$'\n'*}"

	local bare_repo="${repo_info##*$'\n'}"
	repo_info="${repo_info%$'\n'*}"

	local inside_gitdir="${repo_info##*$'\n'}"
	local gitdir="${repo_info%$'\n'*}"

	local conflict_state="" gitdir_state="" rebase_state="" worktree_state=""

	__git_conflict_status
	if [ "true" = "${inside_gitdir}" ]; then
		__git_gitdir_status
	elif [ "true" = "${inside_worktree}" ]; then
		__git_worktree_status
		__git_rebase_status
	fi

	echo -e " ${GIT_DELIMITER_COLOR}[${gitdir_state}${rebase_state}${worktree_state}${conflict_state}${GIT_DELIMITER_COLOR}]"

	return $exit
}
