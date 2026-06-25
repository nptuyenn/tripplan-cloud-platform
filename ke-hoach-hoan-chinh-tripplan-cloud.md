# TripPlan Cloud Platform — Kế hoạch hoàn chỉnh (đã tích hợp cải thiện)

> AWS Networking + Terraform + CI/CD + Docker + EKS + Argo CD + Observability
> Stack app (tối giản — app chỉ là "phương tiện" để demo hạ tầng): **React tối giản (SPA) + Node.js/Express (API) + Postgres + S3**

---

## Tiến độ hiện tại

| Phase | Trạng thái | Ghi chú |
|---|---|---|
| Phase 0 — Bootstrap | ✅ Xong phần code | Đã có `infra/bootstrap` (main/outputs/variables/versions.tf + tfvars example). **Cần chốt state bootstrap và xác nhận OIDC khi apply thật.** |
| Phase 1 — Networking | 🔨 Đang làm | Đã có module `vpc/`, `vpc-endpoints/`, `infra/envs/dev`, route table, NAT theo AZ, SG nền, NACL, Flow Logs, S3/ECR/SSM/Logs endpoints. Còn: vẽ sơ đồ, `terraform plan/apply`, verify route/data subnet. |
| Phase 2–7 | ⬜ Chưa | |

### Việc cần chốt nốt cho Phase 0 (quan trọng — phát hiện từ cấu trúc bạn gửi)

1. **State của bootstrap đang là local** (`terraform.tfstate` + `.backup` nằm trong `infra/bootstrap/`). Đây là tình huống "con gà–quả trứng" bình thường vì bootstrap *tạo ra* chính cái S3 bucket. Hai cách xử lý đúng:
   - **(Khuyến nghị)** Sau khi bucket được tạo, chạy `terraform init -migrate-state` để **đẩy luôn state của bootstrap vào S3 bucket** đó → không còn state local.
   - Hoặc giữ local nhưng **bắt buộc `.gitignore`** cả `terraform.tfstate*`.
2. **`.gitignore` phải có:** `*.tfstate`, `*.tfstate.*`, `.terraform/`, và `*.tfvars` (chỉ commit `terraform.tfvars.example`). Tuyệt đối không commit state/tfvars lên Git.
3. **Giữ lại** `.terraform.lock.hcl` trong Git (đây là file *nên* commit để khoá version provider).
4. Các `.gitkeep` thừa trong thư mục đã có file thật đã được xoá; chỉ giữ placeholder cho module/env chưa triển khai.

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
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── ecr/
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
│  ┌─── Private Subnet — EKS Worker Nodes (10.0.10.0/23) ───┐ │
│  │  EKS: VPC CNI (VPC-native pod networking)               │ │
│  │  NetworkPolicy enforced │   IRSA (pod-level AWS access)  │ │
│  └────────────┬──────────────────────────────────────────┘ │
│  ┌─── Data Subnet (10.0.20.0/24) — No public access ───────┐│
│  │  RDS Postgres                                             ││
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
| IaC | Terraform — VPC, EKS, RDS, S3, ALB, CloudFront, Route 53, VPC Endpoints |
| State | S3 backend + DynamoDB lock |
| Networking | Public/Private/Data subnet, NAT GW, SG, NACL, VPC Endpoint, VPC Flow Logs |
| Frontend | React tối giản → S3 + CloudFront |
| API tier | Node.js/Express, Postgres (RDS), S3 (ảnh cover) |
| Secrets | AWS Secrets Manager + External Secrets Operator |
| Container | Docker (multi-stage), ECR (scan-on-push) |
| K8s | EKS, managed node groups, VPC CNI, NetworkPolicy, Ingress, AWS Load Balancer Controller, IRSA |
| CI | GitHub Actions (OIDC, test, Trivy scan, tfsec/checkov) |
| CD | Argo CD (GitOps, auto-sync, sync-wave, self-heal) |
| Observability | Prometheus, Grafana, Loki, Tempo/OTel, CloudWatch |
| Access | SSM Session Manager |

---

## 4. Roadmap theo Phase

> Quy tắc: xong **Deliverable** của phase mới sang phase sau. Mỗi phase đều phải `apply` được **và** `destroy`/rollback được.

---

### Phase 0 — Bootstrap & nền tảng repo  ✅ ĐÃ XONG
**Mục tiêu:** Dựng phần "móng" để mọi thứ về sau an toàn và tái lập được.

- `infra/bootstrap/`: tạo **S3 bucket** (bật versioning + SSE) chứa Terraform state + **DynamoDB table** cho state lock.
- Tạo **GitHub OIDC provider** trên AWS + IAM role mà GitHub Actions assume (least-privilege).
- Định nghĩa **tagging strategy** chung (Project, Env, Owner, ManagedBy=Terraform) — dùng cho cost allocation.
- Khởi tạo repo, `docs/adr/0001-architecture-decisions.md` ghi 7 quyết định ở mục 0.

**Deliverable:** State backend hoạt động (`terraform init` dùng S3 backend OK); OIDC role assume được từ Actions; ADR đầu tiên.

> **Còn lại để đóng Phase 0 hoàn toàn:** (1) migrate state bootstrap vào S3 hoặc gitignore state local; (2) thêm `.gitignore` đúng (state/tfvars/.terraform); (3) xác nhận một workflow GitHub Actions assume được OIDC role. Xem "Việc cần chốt nốt" ở đầu file.

---

### Phase 1 — Terraform: AWS Networking Foundation  🔨 ĐANG LÀM
**Mục tiêu:** Hạ tầng mạng 3-tier với isolation đầy đủ.
**Đã có:** module `vpc/`, `vpc-endpoints/`, và `infra/envs/dev` (main/outputs/variables/backend/tfvars example).

- Module `vpc/`: public / private / data subnet trên **2 AZ**.
- Internet Gateway, **NAT Gateway theo AZ** cho private subnet egress, route tables.
- Security Group (stateful) nền cho ALB, EKS nodes, RDS; NACL (stateless) theo từng tier.
- Module `vpc-endpoints/`: **ecr.api + ecr.dkr (interface)** + **S3 (gateway)** — bắt buộc đủ 3 để pull/push ECR private.
- Đã thêm CloudWatch Logs endpoint để log traffic đi private.
- Bật **VPC Flow Logs** → CloudWatch (dùng debug network ở phase sau).
- Bật **SSM** (VPC endpoints `ssm`, `ssmmessages`, `ec2messages`) để Session Manager chạy không cần internet.

**Còn lại để đóng Phase 1:** vẽ sơ đồ network; chạy `terraform plan/apply`; chứng minh data subnet không có route ra internet; xác nhận private subnet đi ECR/S3/SSM qua endpoints.

---

### Phase 2 — Ứng dụng TripPlan (tối giản) + Docker + ECR
**Mục tiêu:** Có một artifact đủ để deploy và demo hạ tầng — KHÔNG làm sản phẩm hoàn chỉnh.

**Nguyên tắc:** giữ đúng các endpoint *chạm* vào từng thành phần hạ tầng, cắt mọi thứ còn lại.

**API (Express) — chỉ ~6 endpoint:**
| Endpoint | Mục đích / hạ tầng nó demo |
|---|---|
| `GET /healthz` | liveness probe |
| `GET /readyz` | readiness probe — chỉ check kết nối **Postgres** |
| `GET /metrics` | `prom-client` — để Prometheus scrape |
| `GET /trips` + `POST /trips` | CRUD đơn giản vào **RDS Postgres** → demo data subnet isolation |
| `GET /places?q=...` | gọi 1 API public ngoài (Nominatim) → traffic đi qua **NAT Gateway** (giải thích vì sao cần NAT) |
| `POST /trips/:id/cover` | sinh **presigned URL S3** → demo **IRSA** (pod lấy quyền AWS không cần access key) |

**DB schema:** chỉ **1 bảng** `trips` (id, destination, start_date, end_date, cover_image_url). Bỏ `users`, `trip_days`, `activities`.

**Đã cắt khỏi bản gốc:** auth/đăng ký-đăng nhập, sharing public link, timeline nhiều ngày, profile, render bản đồ, **Redis/ElastiCache**.

**Frontend (React tối giản):** 1–2 trang là đủ — một trang list + tạo trip, gọi API qua `fetch`. Build tĩnh, đẩy lên **S3 + CloudFront**. Mục đích chỉ để có cái demo CDN/TLS, không đầu tư UI.

**Việc cần làm:**
- API 6 endpoint ở trên + kết nối Postgres.
- **Migration:** `node-pg-migrate` (1 file tạo bảng `trips`); để trong `backend/migrations/`; chạy bằng **k8s Job/hook** ở Phase 5.
- **Secrets:** DB password do Terraform sinh `random_password` → ghi **Secrets Manager**; backend đọc qua env do ESO inject (Phase 3). Không hardcode.
- **Docker:** Dockerfile multi-stage cho API; build & push **ECR (qua VPC Endpoint)**, tag = git SHA.
- **Frontend:** React build tĩnh, cấu hình base URL API.

**Deliverable:** `docker-compose up` chạy local (API + Postgres + frontend); image API trên ECR; ECR scan-on-push không có critical CVE.

---

### Phase 3 — EKS Cluster + Kubernetes Networking
**Mục tiêu:** App chạy trên EKS, mạng đúng thiết kế và đồng nhất với AWS managed services.

- Terraform provision **EKS cluster** + managed node group trong private subnet.
- IAM role cho node để **pull ECR** và vận hành node group.
- Cài **AWS Load Balancer Controller** bằng Helm, dùng **IRSA** để cấp quyền AWS cho controller.
- Cài **External Secrets Operator**, tạo `ExternalSecret` map từ Secrets Manager → k8s Secret.
- Deploy API: Deployment + Service + **Ingress**.
  - Với EKS + VPC CNI, dùng AWS Load Balancer Controller và ALB target-type `ip` để route trực tiếp tới pod IP trong VPC.
- **NetworkPolicy:** dùng EKS-compatible network policy path (Amazon VPC CNI network policy hoặc Cilium/Calico nếu chọn sau), viết policy chặn data tier chỉ cho phép từ API pod, test deny mặc định.
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

### Phase 7 — Documentation & Polish
**Mục tiêu:** Đóng gói để gắn vào CV/LinkedIn.

- README hoàn chỉnh: architecture diagram, **cost breakdown**, lessons learned, link tới ADR.
- Video/GIF ngắn: CI trigger, Argo rollback, Grafana dashboard + alert, EKS demo.
- Dọn repo; **`terraform destroy`** toàn bộ sau khi quay.

**Deliverable:** Repo sẵn sàng cho portfolio.

---

## 5. Ghi chú vận hành quan trọng

- **Luôn `terraform destroy`** sau demo để tránh phát sinh chi phí.
- Cảnh báo chi phí: **EKS control plane ~$0.10/giờ (~$72/tháng)**; **NAT Gateway ~$32/tháng/cái + phí data** — bạn đang để **NAT theo AZ** (2 AZ ≈ ~$64/tháng), HA tốt hơn nhưng đắt gấp đôi; với môi trường dev có thể hạ xuống **1 NAT dùng chung** để tiết kiệm. Bật khi cần, `destroy` khi xong.
- **OIDC > access key** cho CI — vừa an toàn vừa là điểm cộng phỏng vấn.
- **Không commit secret/cleartext** lên Git; mọi credential qua Secrets Manager.
- **Image dùng tag git SHA**, không `latest`, để Argo phát hiện thay đổi và rollback chính xác.
- Đủ **3 VPC endpoint cho ECR** (ecr.api + ecr.dkr + S3 gateway) nếu không pull image sẽ fail.

---

## 6. Thứ tự ưu tiên nếu thiếu thời gian

| Bắt buộc làm | Có thể làm sau | Nâng cao (nếu còn thời gian) |
|---|---|---|
| Phase 0,1,2,3 (state, VPC, app, EKS) | Phase 4,5 (CI/CD) | Tempo/OTel tracing |
| Secrets Manager + ESO | Phase 6 observability | WAF, CloudFront cho API |
| OIDC | Phase 7 polish | cosign/SBOM, ApplicationSet đa env |
| `/healthz` + `/readyz` + `/metrics` | SLO/alert | Multi-AZ RDS |

> Cốt lõi: làm **đúng và sâu** state/secrets/GitOps/networking quan trọng hơn nhồi thêm công cụ.
