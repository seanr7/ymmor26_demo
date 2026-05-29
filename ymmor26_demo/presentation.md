# Claude Code

Claude Code is an AI-powered CLI tool (and IDE extension) that lets
  you interact with Claude directly inside your development
  environment. You describe what you want in plain English — "explain 
  this file," "implement this algorithm," "find the bug in my
  solver" — and Claude reads your files, writes and edits code, runs
  shell commands, and navigates your project autonomously. Unlike a
  chat interface, Claude Code operates in your codebase with full
  context, so it can handle multi-step tasks like refactoring,
  debugging, or setting up experiments end-to-end.

## 1. Agent vs Web view
- Mess around in CLI tool
    - /model, /context, /effort
- agent or CLI tool has all context
- more custom configurations and control compared to web app
- /usage 

## 2. CLAUDE.md 

From the docs (https://code.claude.com/docs)

"CLAUDE.md is a markdown file you add to your project root that Claude
 Code reads at the start of every session. Use it to set coding standards, 
 architecture decisions, preferred libraries, and review checklists."

- Walk through pre-created CLAUDE.md
  - One CLAUDE.md per project
  - When you launch Claude Code from within your project directory (e.g., this project)
    it will automatically load a CLAUDE.md file in that project as its project instructions.
- Highlight version control instructions (no git for the demo though)
- Highlight project description. What it does ...
    - Describes the project (high-level); what is it for (comparing canonical MOR algorithms)
    - Gives a bechmark (not necessary, can writing for multiple)
    - Algorithms to-be-implemented
    - Metrics by which the experiments to be judged
    - Axes (think "knobs to tune") along which the experiment to run. 
    - Obviously, this is very specific, but one could see how you could set up
      a CLAUDE.md file for, e.g., generating the numerical experiments in a 
      paper.
- "Stack", i.e., what code / packages / toolboxes are you using.
  - MATLAB, and don't assume toolboxes are installed. 
- Coding styles
  - This is useful to tell Claude how you want your code to be written.
  - For this project, I tell Claude that I want separate MTALAB files for everything that is 
    implemenetd. 
  - Experiment itself is run separate.
  - Naming conventions for variables, etc. 
- Similarly, define plotting convention
- Describes how directory should be structured (subdirs for driver functions, results/logs, data, ...)

## 3. Skills
- what they are: reusable repo-specific instructions
- why they matter: avoid repeating prompts; enforce local conventions
- Stored in skills dir, each skill has a SKILL.md
- Invoke in CLI using /_skill_name_, e.g., /my-code-style
- For writing skills based on styles, preferences, etc., you can use Cluade
  - clean code that you've written yourself is the best training data you can give to Claude!
  - e.g., "Read this repo, generate a 'code-style skill', based on my syntax, coding style, etc.
- how to write them:
  - be concrete
  - say when to use them, invoke with /, e.g., /grill-me 
  - include examples
  - encode style, testing, numerical checks
- docs: https://code.claude.com/docs/en/skills#types-of-skill-content

## 4. Demo: my-code-style skill
- Use "/my-code-style" as example
  - Note there is some redundancy relative to the CLAUDE.md, this is because skills can be 
    invoked from anywhere (just need to configure properly)
  - Main rules for the code I write.
  - Highlight the function header description. Provides an example of my very picky comment style and rules
  - How sections in code are labeled. 
  - Variable naming conventions (repeat); also specifies that I ALWAYS use camelCase for my variable names,
    and snake_case for file / functions names 
  - Can even encode implementation specific conventions. 
    - For instance, always use / to solve linear systems of equations.
    - Pre-allocate matrices before loops, always. 
    - Scalar pre-computation. 
  - It is very helpful to show "good / bad" implementations of a function body. 
  - Runme script structure ..

- Implement experiment, with and without CLAUDE.md and skill, using prompt:
  "Implement a MATLAB MOR comparison suite for the ISS 1412 benchmark
    (1412 states, 3 inputs, 3 outputs, loaded from iss12a.mat). Implement
    Balanced Truncation, IRKA, and POD from scratch — no toolboxes.
    Sweep reduced order r = [5, 10, 20, 40, 80] and collect five metrics:
    wall-clock timing, H∞ error, H2 error, transfer function error over
    frequency, and time-domain output error (impulse, step, and random
    inputs). Save one figure per metric, with all three methods as
    labeled curves over r."
- Compare!
- Notes during the "good (skills + CLAUDE.md)"
  - Got IRKA wrong.
  - Corrected itself while implementing Bartels-Stewart.

## 4a. Other small skills
- Quickly demo /code-walk
- Quickly demo /grill-me
- Shout out https://github.com/mattpocock/skills

## 5. Other useful skill ideas
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

## Useful Commands

- `/context` — Shows current token usage broken down by category (system prompt, tools, skills, messages, etc.)
- `/model` — Switch the AI model Claude Code is using for the session.
- `/compact` — Manually summarize and compress conversation history to free up context space.
- `/rename` — Rename the current conversation/session.
- `/branch` — Create a new conversation branch from the current point.
- `/memory` — View and edit your persistent memory files (like CLAUDE.md).
- `/clear` — Clear the current conversation and start fresh with a clean context.
- `/plan` - Plan a project

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
- Some other closing thoughts
  - The only reason I knew how to give Claude all these instructions was because 
    I understood the methods intimately and wrote the initial code myself. No substitute
    for writing your own code when doing something new! 
  - Jury is out on, is it more efficient to design these workflows? Or, just write the code.