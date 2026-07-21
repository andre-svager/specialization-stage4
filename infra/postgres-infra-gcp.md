 ConfigMap com scripts SQL (mais simples, sem Docker)
O Postgres oficial roda automaticamente qualquer .sql/.sh que estiver em /docker-entrypoint-initdb.d/ na primeira inicialização. Como você não tem PVC (usa emptyDir), isso na prática roda toda vez que o pod reinicia — o que é ótimo para estudo, porque você sempre volta com os schemas prontos.

1. Crie o script de init com os 3 bancos
sql-- init-multi-db.sql
CREATE DATABASE auth_db;
CREATE DATABASE flag_db;
CREATE DATABASE target_db;

\c auth_db
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    key VARCHAR(255) UNIQUE NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now()
);

\c flag_db
CREATE TABLE flags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    enabled BOOLEAN DEFAULT false
);

\c target_db
CREATE TABLE events (
    event_id VARCHAR(255) PRIMARY KEY,
    flag_name VARCHAR(255),
    user_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT now()
);
2. Transforme em ConfigMap
bashkubectl create configmap postgres-init-scripts --from-file=init-multi-db.sql

3. Atualize o postgres.yaml para montar o ConfigMap
yamlapiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_PASSWORD: "senha123"
  POSTGRES_USER: "postgres"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: postgres-secret
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
            - name: init-scripts
              mountPath: /docker-entrypoint-initdb.d
      volumes:
        - name: postgres-storage
          emptyDir: {}
        - name: init-scripts
          configMap:
            name: postgres-init-scripts
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP

Note que removi o POSTGRES_DB do Secret — não precisamos mais dele, já que os 3 bancos são criados pelo script.

4. Aplicar
bashkubectl apply -f postgres.yaml
kubectl rollout restart deployment/postgres   # se o pod já existia, force recriar pra rodar o init

5. Verificar
bashkubectl port-forward svc/postgres 5432:5432
bashpsql "postgres://postgres:senha123@localhost:5432/postgres" -c "\l"
Você deve ver auth_db, flag_db, target_db na lista.