# GitHub issue tracker

Issues and specs live in GitHub Issues for `guillermo-rebolledo/music-discovery-ios`. Use the `gh` CLI from the repo root. Add `--repo guillermo-rebolledo/music-discovery-ios` when running outside the checkout.

## Issue operations

- Publish a ticket or spec with `gh issue create --title "..." --body-file <file>`.
- Fetch a ticket with `gh issue view <number> --json number,title,body,labels,comments`.
- List tickets with `gh issue list --state open --json number,title,body,labels,comments`. Adjust `--state` and add `--label` to filter as needed.
- Create a sub-issue with `gh issue create --parent <parent> ...`. Attach an existing issue with `gh issue edit <parent> --add-sub-issue <child>`. If sub-issues are unavailable, add `Part of #<parent>` to the child body.
- Record a dependency with `gh issue edit <child> --add-blocked-by <blocker>`. If native dependencies are unavailable, add `Blocked by: #<blocker>` to the child body.
- Comment with `gh issue comment <number> --body-file <file>`.
- Apply or remove labels with `gh issue edit <number> --add-label "<label>"` or `gh issue edit <number> --remove-label "<label>"`.
- Close an issue with `gh issue close <number>`. Use `--comment` when the close needs a short explanation.

## Pull requests in triage

**PRs as a request surface: no.**

If enabled, use `gh pr view <number> --comments` and `gh pr diff <number>` to inspect a PR. List open external PRs with `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`. Use `gh pr comment`, `gh pr edit`, and `gh pr close` to triage them. GitHub shares numbering between issues and PRs. Resolve a bare number with `gh pr view <number>`, then fall back to `gh issue view <number>`.

## Wayfinding operations

- Create a map issue with the `wayfinder:map` label and Notes, Decisions-so-far, and Fog sections.
- Link each decision ticket as a sub-issue and use its `wayfinder:<type>` label (`research`, `prototype`, `grilling`, or `task`). If sub-issues are unavailable, add each child to the map's task list and link back from the child.
- Pick the first open child in map order with no assignee and no open blockers. For native dependencies, check `issue_dependencies_summary.blocked_by` in the GitHub issue API. For body-based dependencies, check the state of each issue listed under `Blocked by:`.
- Claim the ticket with `gh issue edit <number> --add-assignee @me`.
- Resolve the ticket with a comment and close it, then add the decision and a link to the map's Decisions-so-far section.
