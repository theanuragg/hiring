# Deploy cheat sheet

## 1. Config

```bash
cd may-2026/devops/quickstart
cp .deploy.env.example .deploy.env
nano .deploy.env
```

```bash
DIGITALOCEAN_TOKEN=dop_v1_YOUR_TOKEN
GITHUB_USER=theanuragg
```

## 2. Push to GitHub (required)

```bash
cd /Users/anurag/coding/git/hiring
git add may-2026/devops/quickstart/
git commit -m "DevOps assignment: DigitalOcean quickstart deployment"
git push -u origin main
```

Verify: https://github.com/theanuragg/hiring/tree/main/may-2026/devops/quickstart/deploy

## 3. Deploy

```bash
export DIGITALOCEAN_TOKEN="dop_v1_..."
cd may-2026/devops/quickstart
chmod +x scripts/*.sh
./scripts/deploy.sh
```

## 4. Test (after 10-20 min)

```bash
./scripts/test-api.sh
```

## 5. Fix VMs if API down (fork was empty on first boot)

```bash
ssh root@64.227.180.170
cd /opt/alchemyst-hiring && git pull origin main
bash may-2026/devops/quickstart/deploy/scripts/bootstrap-api-gateway.sh
```

Workers from gateway:

```bash
ssh root@10.20.0.3
cd /opt/alchemyst-hiring && git pull && bash may-2026/devops/quickstart/deploy/scripts/bootstrap-caller-worker.sh

ssh root@10.20.0.4
cd /opt/alchemyst-hiring && git pull && bash may-2026/devops/quickstart/deploy/scripts/bootstrap-inference-worker.sh
```

## 6. Destroy

```bash
./scripts/destroy.sh
```
