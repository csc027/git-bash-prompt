# Copyright (c) 2016 Marc Meadows
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
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
	GIT_CLEAN_STATUS_COLOR="\033[0;96m"
	GIT_DELIMITER_COLOR="\033[0;93m"
	GIT_ERROR_COLOR="\033[0;31m"
	GIT_RESET_COLOR="\033[0m"
	GIT_STAGED_COLOR="\033[0;32m"
	GIT_UNSTAGED_COLOR="\033[0;31m"
	GIT_UNCOMMITTED_COLOR="\033[0;96m"
fi

git_bash_prompt() {
	local -i ahead=0 behind=0 index_added=0 index_deleted=0 index_modified=0 index_unmerged=0 worktree_added=0 worktree_deleted=0 worktree_modified=0 worktree_unmerged=0
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

	local vcstate index_state delimiter_state worktree_state working_state

	if [[ -n "${error}" ]]; then
		vcstate=" ${GIT_DELIMITER_COLOR}[${GIT_ERROR_COLOR}${error}${GIT_DELIMITER_COLOR}]"
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
			delimiter_state=" ${GIT_DELIMITER_COLOR}|"
		fi
		if ((worktree_added > 0 || worktree_modified > 0 || worktree_deleted > 0)); then
			worktree_state=" ${GIT_UNSTAGED_COLOR}${GIT_ADDED_INDICATOR}${worktree_added} ${GIT_MODIFIED_INDICATOR}${worktree_modified} ${GIT_DELETED_INDICATOR}${worktree_deleted}"
		fi

		if ((worktree_added > 0 || worktree_modified > 0 || worktree_deleted > 0)); then
			working_state=" ${GIT_UNSTAGED_COLOR}${GIT_UNSTAGED_INDICATOR}"
		elif ((index_added > 0 || index_modified > 0 || index_deleted)); then
			working_state=" ${GIT_UNCOMMITTED_COLOR}${GIT_UNCOMMITTED_INDICATOR}"
		fi

		vcstate=" ${GIT_DELIMITER_COLOR}[${status_state}${index_state}${delimiter_state}${worktree_state}${working_state}${GIT_DELIMITER_COLOR}]"
	fi

	echo -e "${vcstate}"
}
