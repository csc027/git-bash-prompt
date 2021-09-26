# Git Bash Prompt
Git Bash Prompt is a simple prompt for bash to display git status information.

## Usage
In .bashrc do the following:
```bash
	. .git-prompt.bash
	PS1="\u@\h:\w\$(git_bash_prompt)\$ "
					^^^^^^^^^^^^^^^^^^^^^
```
NOTE: The backslash before the $ is required.

## Prompt
![~/dev/git-bash-prompt [master ≡] $](assets/sample-prompt.png)

![~/dev/git-bash-prompt [master ≡ +1 ~0 -0 | +1 ~0 -0 !] $](assets/long-sample-prompt.png)
