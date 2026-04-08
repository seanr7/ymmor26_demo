# Claude Code

## 1. Framing
- audience: lab using Claude for numerical / research code
- goal: practical workflow, not full feature tour
- theme: make Claude Code fit your repo and habits

## 2. Skills
- what they are: reusable repo-specific instructions
- why they matter: avoid repeating prompts; enforce local conventions
- how to write them:
  - be concrete
  - say when to use them
  - include examples
  - encode style, testing, numerical checks
- docs: https://code.claude.com/docs/en/skills#types-of-skill-content

## 3. Demo: code-style skill
- show small repo/file
- apply a code-style skill
- make one small edit
- compare with/without the skill

## 4. Other useful skill ideas
- numerical code conventions
- plotting conventions
- validation / sanity checks
- experiment script structure
- review skill for unstable numerics / missing tests

## 5. Branches vs worktrees
**Branches**
- pointer to commits
- one checked-out branch per working directory
- switching changes files in place

**Worktrees**
- separate working directories for one repo
- each can have a different branch checked out
- good for parallel tasks without stashing/switching

**Key difference**
- branch = line of history
- worktree = separate workspace

## 6. Useful commands
- `/context`
- `/model`
- `/compact`
- `/rename`
- `/branch`
- `/memory`

## 7. Token usage
- compressing context 
- running out of tokens and reverting
- running out of tokens and saving a session

## 8. Other Tips
- develop your own workflow taste
- start from one repo you know well
- make Claude imitate code/style you actually like
- turn that into a `SKILLS` file

## 9. Closing
- Claude Code works best when:
  - repo is organized
  - workflow is explicit
  - conventions are written down
- Subscription tiers