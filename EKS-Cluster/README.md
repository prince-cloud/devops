# EKS Cluster: Bring Down / Bring Up

Run all commands **on the Jenkins server** (it has `eksctl`, `kubectl`, `helm` and `aws`).

```bash
cd ~/devops/EKS-Cluster     # wherever this repo is cloned on the server
```

---

## Bring DOWN (stop paying)

```bash
./down.sh
```

Type `yes` when asked. Takes about 15 minutes.

Then, to also stop the Jenkins server (optional, from your laptop or AWS console):

```bash
aws ec2 stop-instances --instance-ids i-0de710b503549487a --region us-east-1
```

**Note:** the database data is deleted with the cluster.

---

## Bring UP

**1. Start the Jenkins server** (if you stopped it)

```bash
aws ec2 start-instances --instance-ids i-0de710b503549487a --region us-east-1
```

Its public IP changes. Get the new one from the EC2 console, then SSH in.

**2. Run the script**

```bash
./up.sh
```

Takes about 25 minutes. At the end it prints:
- the **load balancer address**
- the **Argo CD URL and password**

**3. Update DNS in DigitalOcean**

Edit the `3tier-devops` CNAME record of `princethedev.com` → paste the load balancer address.

**4. Open the app:** http://3tier-devops.princethedev.com (use `http`, not `https`)

**5. Fix Jenkins/SonarQube after the IP change** (only if you stopped the Jenkins server)

Check SonarQube is running on the server: `docker ps` (if not: `docker start sonar`)

In Jenkins (`http://<NEW-IP>:8080`) → Manage Jenkins → System:

| Setting | Value |
|---|---|
| Jenkins Location → Jenkins URL | `http://<NEW-IP>:8080/` |
| SonarQube servers → `sonar-server` → Server URL | `http://localhost:9000` |

In SonarQube (`http://<NEW-IP>:9000`) → Administration → Configuration → Webhooks:

| Webhook | URL |
|---|---|
| Jenkins | `http://10.0.1.130:8080/sonarqube-webhook/` |

In GitHub (only if you use a webhook to trigger builds) → repo Settings → Webhooks:

| Webhook | URL |
|---|---|
| Jenkins | `http://<NEW-IP>:8080/github-webhook/` |

`localhost` and `10.0.1.130` (the private IP) never change, so once set, only the **Jenkins URL** and **GitHub webhook** need the new IP each time.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `down.sh` says a stack still exists | CloudFormation console → select the stack → Stack actions → Edit termination protection → Off → Delete |
| App pods show `ImagePullBackOff` | Image tag in `Kubernetes-Manifests-file/*/deployment.yaml` doesn't exist in ECR. Run the Jenkins pipeline, or set a tag that exists |
| `up.sh` fails: "already exists" | The old cluster wasn't fully deleted. Run `./down.sh` again |
| Load balancer address never appears | `kubectl logs -n kube-system deploy/aws-load-balancer-controller` |
