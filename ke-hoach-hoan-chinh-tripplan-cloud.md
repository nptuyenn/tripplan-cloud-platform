# TripPlan Cloud Platform — Kế hoạch hoàn chỉnh (đã tích hợp cải thiện)

> AWS Networking + Terraform + CI/CD + Docker + k3s/EKS + Argo CD + Observability
> Stack app: **React (SPA) + Node.js/Express (API) + Postgres + Redis + S3**

---

## 0. Quyết định kiến trúc chốt trước khi bắt đầu

Để tránh mơ hồ về sau, chốt sẵn các quyết định sau (và ghi vào `docs/adr/`):

1. **Frontend = React SPA tĩnh**, deploy lên **S3 + CloudFront**. Express **chỉ làm API** (`/api/...`). → tận dụng CDN/WAF/TLS, tách rõ frontend/backend.
2. **State Terraform** lưu remote: **S3 backend + DynamoDB lock**. Không bao giờ dùng local state.
3. **Secrets** quản lý bằng **AWS Secrets Manager**, đưa vào cluster qua **External Secrets Operator (ESO)**. Không hardcode.
4. **Auth AWS từ CI** dùng **OIDC** (GitHub → AWS), không dùng access key.
5. **Image tag = git SHA** (immutable), không dùng `latest`.
6. **k8s config** dùng **Kustomize** (`base/` + `overlays/dev`, `overlays/prod`). Helm chỉ dùng cho thành phần bên thứ ba (Prometheus, Argo, ESO...).
7. **Truy cập node** bằng **SSM Session Manager**, bỏ bastion + bỏ SSH inbound.

---

## 1. Cấu trúc thư mục (monorepo)

```
tripplan-cloud-platform/
├── frontend/                 # React SPA
│   ├── src/
│   ├── Dockerfile            # chỉ dùng nếu serve qua container; mặc định build tĩnh → S3
│   └── package.json
├── backend/                  # Express API (TripPlan)
│   ├── src/
│   │   ├── routes/
│   │   ├── db/
│   │   └── metrics.js        # expose /metrics (prom-client)
│   ├── migrations/           # DB migration files
│   ├── Dockerfile            # multi-stage
│   └── package.json
├── infra/
│   ├── bootstrap/            # S3 state bucket + DynamoDB lock + OIDC provider (Phase 0)
│   ├── modules/
│   │   ├── vpc/
│   │   ├── k3s-ec2/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── ecr/
│   │   ├── elasticache/
│   │   └── vpc-endpoints/
│   └── envs/
│       ├── dev/
│       └── prod/
├── k8s/                      # Argo CD watch thư mục này
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
├── argocd/                   # Application / ApplicationSet manifests (app-of-apps)
├── observability/            # Prometheus/Grafana/Loki/Tempo configs
├── .github/workflows/
│   ├── ci-backend.yml
│   ├── ci-frontend.yml
│   └── infra-validate.yml    # fmt/validate/tfsec/checkov
├── docs/
│   └── adr/                  # Architecture Decision Records
└── README.md
```

---

## 2. Kiến trúc tổng quan

```
Internet/User
     │
Route 53 (DNS) + ACM (TLS)
     │
     ├──► CloudFront ──► S3 (React SPA tĩnh)        # Frontend
     │
     └──► CloudFront/ALB + AWS WAF                   # API
              │
┌────────────────────── VPC 10.0.0.0/16 ──────────────────────┐
│  Internet Gateway                                            │
│  ┌─── Public Subnet (10.0.1.0/24, 10.0.2.0/24, Multi-AZ) ──┐ │
│  │  ALB  │  NAT Gateway                                     │ │
│  └────────────┬──────────────────────────────────────────┘ │
│  ┌─── Private Subnet — K8s Worker Nodes (10.0.10.0/23) ───┐ │
│  │  k3s: Flannel overlay   |   EKS: VPC CNI (VPC-native)   │ │
│  │  NetworkPolicy enforced │   IRSA (pod-level AWS access)  │ │
│  └────────────┬──────────────────────────────────────────┘ │
│  ┌─── Data Subnet (10.0.20.0/24) — No public access ───────┐│
│  │  RDS Postgres  │  ElastiCache Redis                      ││
│  └────────────────────────────────────────────────────────┘│
│  VPC Endpoints: ecr.api + ecr.dkr (interface) + S3 (gateway)│
│  Security: Security Group (stateful) · NACL (stateless)     │
│  Access: SSM Session Manager (không SSH, không bastion)     │
└────────────────────────────────────────────────────────────┘

Observability: VPC Flow Logs · CloudWatch · Prometheus · Grafana · Loki · Tempo(OTel)
```

---

## 3. Stack công cụ đầy đủ

| Layer | Công cụ |
|---|---|
| IaC | Terraform — VPC, EC2/EKS, RDS, ElastiCache, S3, ALB, CloudFront, Route 53, VPC Endpoints |
| State | S3 backend + DynamoDB lock |
| Networking | Public/Private/Data subnet, NAT GW, SG, NACL, VPC Endpoint, VPC Flow Logs |
| Frontend | React SPA → S3 + CloudFront |
| API tier | Node.js/Express, Postgres (RDS), Redis (ElastiCache), S3 (ảnh cover) |
| Secrets | AWS Secrets Manager + External Secrets Operator |
| Container | Docker (multi-stage), ECR (scan-on-push) |
| K8s | k3s (dev) → EKS (demo), NetworkPolicy, Ingress, ALB Controller, IRSA |
| CI | GitHub Actions (OIDC, test, Trivy scan, tfsec/checkov) |
| CD | Argo CD (GitOps, auto-sync, sync-wave, self-heal) |
| Observability | Prometheus, Grafana, Loki, Tempo/OTel, CloudWatch |
| Access | SSM Session Manager |

---

## 4. Roadmap theo Phase

> Quy tắc: xong **Deliverable** của phase mới sang phase sau. Mỗi phase đều phải `apply` được **và** `destroy`/rollback được.

---

### Phase 0 — Bootstrap & nền tảng repo
**Mục tiêu:** Dựng phần "móng" để mọi thứ về sau an toàn và tái lập được.

- `infra/bootstrap/`: tạo **S3 bucket** (bật versioning + SSE) chứa Terraform state + **DynamoDB table** cho state lock.
- Tạo **GitHub OIDC provider** trên AWS + IAM role mà GitHub Actions assume (least-privilege).
- Định nghĩa **tagging strategy** chung (Project, Env, Owner, ManagedBy=Terraform) — dùng cho cost allocation.
- Khởi tạo repo, `docs/adr/0001-architecture-decisions.md` ghi 7 quyết định ở mục 0.

**Deliverable:** State backend hoạt động (`terraform init` dùng S3 backend OK); OIDC role assume được từ Actions; ADR đầu tiên.

---

### Phase 1 — Terraform: AWS Networking Foundation
**Mục tiêu:** Hạ tầng mạng 3-tier với isolation đầy đủ.

- Module `vpc/`: public / private / data subnet trên **2 AZ**.
- Internet Gateway, **NAT Gateway** (dev dùng 1 NAT để tiết kiệm; ghi chú trade-off HA), route tables.
- Security Group (stateful) + NACL (stateless) theo từng tier.
- Module `vpc-endpoints/`: **ecr.api + ecr.dkr (interface)** + **S3 (gateway)** — bắt buộc đủ 3 để pull/push ECR private. (Thêm CloudWatch Logs endpoint nếu muốn flow log đi private.)
- Bật **VPC Flow Logs** → CloudWatch (dùng debug network ở phase sau).
- Bật **SSM** (VPC endpoints `ssm`, `ssmmessages`, `ec2messages`) để Session Manager chạy không cần internet.

**Deliverable:** `terraform apply` thành công; sơ đồ network trong README; chứng minh data subnet không có route ra internet.

---

### Phase 2 — Ứng dụng TripPlan + Docker + ECR
**Mục tiêu:** App chạy được, đóng gói image, sẵn sàng cho k8s.

**App:** Web tạo/quản lý lịch trình du lịch theo ngày, tìm địa điểm, chia sẻ public link.

**Các trang (React SPA):** Trang chủ (chuyến đi của tôi + khám phá public) · Đăng nhập/Đăng ký · Tạo chuyến đi · Chi tiết chuyến đi (timeline theo ngày) · Thêm hoạt động (tìm địa điểm qua API bản đồ) · Bản đồ tổng quan · Chia sẻ public (read-only) · Profile.

**DB schema (Postgres):** `users`; `trips` (user_id, destination, start/end date, cover_image_url, is_public, share_token); `trip_days` (trip_id, date); `activities` (trip_day_id, place_name, time, notes, lat, lng).

**Việc cần làm:**
- **API (Express):** auth + CRUD trip/day/activity + Postgres.
- **Migration:** chọn `node-pg-migrate`/Prisma; file đặt trong `backend/migrations/`. Sẽ chạy bằng **k8s Job/hook** ở Phase 5.
- **Probe:** `/healthz` (liveness) **và** `/readyz` (readiness — check DB + Redis connect).
- **Metrics:** expose `/metrics` bằng `prom-client` (chuẩn bị sẵn cho Prometheus, đừng để dồn sang Phase 6).
- **Upload ảnh cover** → S3 qua presigned URL.
- **API bản đồ ngoài** (Nominatim/Google Places) — traffic đi qua **NAT Gateway** (đây là lý do cần NAT, dùng để demo).
- (Tùy chọn) cache kết quả tìm địa điểm bằng **Redis**.
- **Secrets:** DB password do Terraform sinh `random_password` → ghi **Secrets Manager**; backend đọc qua env được ESO inject (ở Phase 3).
- **Frontend:** React build tĩnh, cấu hình base URL API.
- **Docker:** Dockerfile multi-stage cho API; build & push lên **ECR (qua VPC Endpoint)** với tag = git SHA.

**Deliverable:** `docker-compose up` chạy full local (API + Postgres + Redis + frontend); image API trên ECR; ECR scan-on-push không có critical CVE.

---

### Phase 3 — k3s Cluster + Kubernetes Networking
**Mục tiêu:** App chạy trên k8s thật, mạng đúng thiết kế.

- Terraform provision **2 EC2** (private subnet), cài **k3s** (1 server + 1 agent).
- IAM role cho node để **pull ECR**.
- Cài **External Secrets Operator**, tạo `ExternalSecret` map từ Secrets Manager → k8s Secret.
- Deploy API: Deployment + Service + **Ingress**.
  - ⚠️ **Ingress trên k3s khác EKS:** k3s mặc định là **Traefik + Flannel overlay**, pod không có VPC IP. Cách làm thực tế: dùng Ingress (Traefik/Nginx) qua **NodePort** rồi cho **ALB/NLB target-type `instance`** trỏ tới node (không dùng `target-type: ip` như EKS).
- **NetworkPolicy:** k3s có sẵn network policy controller (kube-router) nên policy **có hiệu lực** — viết policy chặn data tier chỉ cho phép từ API pod, test deny mặc định.
- Pod hygiene: `resources.requests/limits`, `securityContext` (non-root, readOnlyRootFS), `livenessProbe`/`readinessProbe`.
- Frontend: deploy React tĩnh lên **S3 + CloudFront** (Terraform).

**Deliverable:** App truy cập qua ALB + CloudFront; NetworkPolicy chặn/cho đúng thiết kế (có bằng chứng test); secret đến từ Secrets Manager chứ không hardcode.

---

### Phase 4 — CI: GitHub Actions Pipeline
**Mục tiêu:** Push code → tự build, kiểm thử, quét bảo mật, đẩy image.

- Workflow `ci-backend.yml`: **lint → test → build → Trivy scan image → push ECR (tag = git SHA) → cập nhật image tag trong `k8s/overlays/dev`**.
- Cập nhật tag bằng `kustomize edit set image ...` rồi commit kèm `[skip ci]` (tránh loop CI↔Argo). *(Hoặc dùng Argo CD Image Updater — ghi rõ lựa chọn trong ADR.)*
- `ci-frontend.yml`: build React → sync lên S3 → CloudFront invalidation.
- `infra-validate.yml`: `terraform fmt -check`, `validate`, **tfsec** + **checkov**.
- Auth AWS bằng **OIDC** (đã setup ở Phase 0), không có secret access key.
- Tối ưu: npm cache, docker layer cache, `concurrency` để hủy run cũ.

**Deliverable:** Push lên `main` → pipeline tự chạy đủ chuỗi; có log Trivy + tfsec; manifest tự được bump tag.

---

### Phase 5 — CD: Argo CD GitOps
**Mục tiêu:** Đổi Git là đổi cluster, tự sync + tự lành.

- Cài **Argo CD**, kết nối repo, watch `k8s/overlays/dev`.
- Cấu trúc **app-of-apps** (hoặc ApplicationSet) trong `argocd/`.
- Bật **auto-sync + self-heal + prune**.
- **DB migration** chạy bằng **Argo PreSync hook (k8s Job)** + **sync-wave** để migration xong mới rollout app.
- Test self-heal: sửa tay resource trên cluster → xem Argo revert.

**Deliverable:** Commit đổi tag → Argo auto deploy; demo migration chạy trước app; rollback (về commit trước) dưới 1 phút.

---

### Phase 6 — Observability đầy đủ
**Mục tiêu:** Nhìn thấy và cảnh báo được mọi thứ.

- **Prometheus + Grafana** (Helm); scrape `/metrics` của app.
- **Loki** cho log tập trung; **Tempo + OpenTelemetry** cho distributed tracing (bộ ba metrics/logs/traces).
- **VPC Flow Logs → CloudWatch** (gắn với debug network từ Phase 1).
- Định nghĩa **SLO** (latency p99, error rate) theo **RED method**.
- **Alert rule:** pod down, latency cao, error rate vượt ngưỡng → demo bằng cách tắt service.

**Deliverable:** Grafana dashboard sống (RED + tài nguyên); trace 1 request xuyên API→DB; demo alert kích hoạt khi tắt service.

---

### Phase 7 — EKS Migration
**Mục tiêu:** Chạy lại trên managed k8s và so sánh thẳng.

- Module Terraform **EKS**; deploy lại app dùng cùng `k8s/base` + overlay riêng.
- **AWS Load Balancer Controller + IRSA**; lúc này dùng được **target-type `ip`** vì **VPC CNI cho pod IP trong VPC** (khác hẳn k3s/Flannel — đây là điểm so sánh hay).
- So sánh **k3s vs EKS**: chi phí (EKS control plane ~$72/tháng), độ phức tạp setup, vận hành, mạng (overlay vs VPC-native), ingress.

**Deliverable:** App chạy trên EKS; bảng/đoạn so sánh k3s vs EKS trong README.

---

### Phase 8 — Documentation & Polish
**Mục tiêu:** Đóng gói để gắn vào CV/LinkedIn.

- README hoàn chỉnh: architecture diagram, **cost breakdown**, lessons learned, link tới ADR.
- Video/GIF ngắn: CI trigger, Argo rollback, Grafana dashboard + alert, EKS demo.
- Dọn repo; **`terraform destroy`** toàn bộ sau khi quay.

**Deliverable:** Repo sẵn sàng cho portfolio.

---

## 5. Ghi chú vận hành quan trọng

- **Luôn `terraform destroy`** sau demo để tránh phát sinh chi phí.
- Cảnh báo chi phí: **EKS control plane ~$0.10/giờ (~$72/tháng)**; **NAT Gateway ~$32/tháng + phí data**; bật khi cần.
- **OIDC > access key** cho CI — vừa an toàn vừa là điểm cộng phỏng vấn.
- **Không commit secret/cleartext** lên Git; mọi credential qua Secrets Manager.
- **Image dùng tag git SHA**, không `latest`, để Argo phát hiện thay đổi và rollback chính xác.
- Đủ **3 VPC endpoint cho ECR** (ecr.api + ecr.dkr + S3 gateway) nếu không pull image sẽ fail.

---

## 6. Thứ tự ưu tiên nếu thiếu thời gian

| Bắt buộc làm | Có thể làm sau | Nâng cao (nếu còn thời gian) |
|---|---|---|
| Phase 0,1,2,3 (state, VPC, app, k3s) | Phase 4,5 (CI/CD) | Tempo/OTel tracing |
| Secrets Manager + ESO | Phase 6 observability | WAF, CloudFront cho API |
| OIDC | Phase 7 EKS | cosign/SBOM, ApplicationSet đa env |
| `/healthz` + `/readyz` + `/metrics` | SLO/alert | Multi-AZ RDS |

> Cốt lõi: làm **đúng và sâu** state/secrets/GitOps/networking quan trọng hơn nhồi thêm công cụ.
