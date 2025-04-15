# LINUXtips-PICK
Projeto final do Programa Intensivo em Containers e Kubernetes | PICK LINUXtips 


INFRAESTRUTURA

No meu projeto, o Cluster irá rodar localmente em uma VM no Hyper-V.

Especificações:

|       VM       |       CPU        |     RAM     |     OS      |
|----------------|------------------|-------------|-------------|
|     Hyper-V    | Xeon 2360 4 Core |     17GB    | Rocky Linux |  


PROVISIONANDO SERVER PARA O CLUSTER.

Rede:

Irei configurar o IP 192.168.1.81/24 de forma static na subrede 192.168.1.x junto com meu gateway, o DNS será do Google (8.8.8.8).

```
nmcli con mod eth0 ipv4.addresses 192.168.1.81/24
nmcli con mod eth0 ipv4.gateway 192.168.1.254
nmcli con mod eth0 ipv4.dns 8.8.8.8
nmcli con mod eth0 ipv4.method manual
```

Reinicie a conexão para aplicar as alterações.

*nmcli con down eth0 && nmcli con up eth0*

Visualizar:

*ip a show eth0
nmcli dev show eth0*


Rede Configurada. -----------------------------------------------------------------


Vamos atualizar o OS.

```
dnf update -y
```

Instale o Git:
```
sudo dnf install -y git
```


VM atualizada e Git instalado, agora vamos para o Docker.

Docker:
```
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```
Vamos instalar o Conterinerd
```
sudo dnf install -y docker-ce docker-ce-cli containerd.io
```

Habilite o service do docker na inicialização.
```
sudo systemctl enable docker --now
```
Verifique a instalação

*docker --version*

![Title](imagens/docker/docker_instalado.png)



Instalando Kubectl

Vamos instalar a versão stable do kubectl, dar permissão para execução e mover a saída para o diretório */usr/local/bin/*
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

Verifique a instalação

*kubectl version --client*

![Title](imagens/kubectl/kubectl.png)



Deploy KinD.

Vamos baixar o kind, dar permissão de execução e mover para o diretório */usr/local/bin/kind*
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Verifique a instalação:

*kind --version*

![Title](imagens/kind/kind.png)


Kind instalado com sucesso. Vamos criar um manifest para deploy do Cluster.


kind-config.yaml
```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "192.168.1.81"  # IP externo do host
  apiServerPort: 17443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"

nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
      - containerPort: 6443
        hostPort: 17445  # Porta do servidor API

  - role: worker
```



Deploy:
```
kind create cluster --name giropops-cluster --config cluster-config.yaml
```

![Title](imagens/kind/1.png)



Vamos verificar se o Cluster subiu corretamente.

Cluster:
*kubectl cluster-info --context kind-giropops-cluster*

Nodes:
*kubectl get nodes*

Se tudo estiver OK, você verá:

    O endereço do API server https://192.168.1.81:17443

    Dois nodes: control-plane e worker com STATUS: Ready


![Title](imagens/kind/2.png)

Cluster funcionando.


Vamos preparar a nossa imagem para deploy.


MELANGE

O Melange é uma ferramenta para construir pacotes para sistemas baseados em 
Alpine Linux e APKO. Ele permite que você crie pacotes .apk que podem ser incluídos em imagens APKO e 
usados em containers leves.


Vamos instalar o Melange.

curl -L https://github.com/chainguard-dev/melange/releases/download/v0.23.6/melange_0.23.6_linux_amd64.tar.gz -o melange.tar.gz
tar -xzf melange.tar.gz

Arquivo extraído, vamos entrar no diretório, dar permissão e mover para /ur/local/bin/melange

cd melange_0.23.6_linux_amd64/

#ls
LICENSE  melange

mv melange /usr/local/bin/
chmod +x /usr/local/bin/melange

![Title](imagens/melange/melange.png)


Teste o Melange:

*melange version*


![Title](imagens/melange/1.png)


APKO


curl -L https://github.com/chainguard-dev/apko/releases/download/v0.10.0/apko_0.10.0_linux_amd64.tar.gz -o apko.tar.gz

tar -xzf apko.tar.gz

cd apko_0.10.0_linux_amd64/

chmod +x apko
sudo mv apko /usr/local/bin/


![Title](imagens/melange/apko.png)


Verifique a versão:

*apko version*


![Title](imagens/melange/1.png)



MELANGE e APKO Instalado com sucesso!



Preparando a imagem giropops-senhas https://github.com/badtuxx/giropops-senhas


Vamos realizar Clone do repo.

git clone https://github.com/badtuxx/giropops-senhas.git
cd giropops-senhas

Gere as chaves:

*melange keygen*

![Title](imagens/melange/3.png)

Agora possuímos 2 chaves, uma privada "melange.rsa" e outra pública "melange.rsa.pub".

Copie as chaves para uma pasta chama keys.

*cp melange.rsa melange.rsa.pub keys*

Renoméie a chave pública:

*cp melange.rsa.pub melange.key*






Vamos criar nosso manifesto melange.yaml

vi melange.yaml

```
package:
  name: giropops-senhas
  version: 0.1
  epoch: 0
  description: empacotamento girpops-senhas LinuxTIPS
  target-architecture:
    - x86_64
  dependencies:
    runtime:
      - python3

environment:
  contents:
    keyring:
      - ./melange.rsa.pub
    repositories:
      - https://dl-cdn.alpinelinux.org/alpine/edge/main
      - https://dl-cdn.alpinelinux.org/alpine/edge/community
    packages:
      - alpine-baselayout-data
      - ca-certificates-bundle
      - busybox
      - gcc
      - musl-dev
      - python3
      - python3-dev
      - py3-pip
      - py3-virtualenv

pipeline:
  - uses: fetch
    with:
      uri: https://github.com/badtuxx/giropops-senhas/archive/refs/heads/main.tar.gz
      expected-sha256: 5743d189589bbcbed3f5f1872feb694d77027599c3c2d7b8514dc0122b043d46
      strip-components: 1

  - name: Build Python application
    runs: |
      set -ex
      EXECDIR="${{targets.destdir}}/usr/bin"
      APPDIR="${{targets.destdir}}/usr/share/giropops-senhas"
      mkdir -p "$EXECDIR" "$APPDIR"

      echo "#!/usr/share/giropops-senhas/venv/bin/python3" > "$EXECDIR/giropops-senhas"
      cat app.py >> "$EXECDIR/giropops-senhas"
      chmod +x "$EXECDIR/giropops-senhas"

      virtualenv "$APPDIR/venv"
      cp -r templates static requirements.txt "$APPDIR/"
      source "$APPDIR/venv/bin/activate"
      pip install -r "$APPDIR/requirements.txt"

update:
  enabled: false
```


Resumo do que ele faz:

    Define um pacote chamado giropops-senhas, versão 0.1.

    Declara dependências do sistema necessárias para compilar e rodar uma app Python (gcc, musl, python3, etc).

    Cria uma pipeline de build, que:

        Prepara diretórios destino.

        Copia e monta o script app.py como um executável (giropops-senhas).

        Cria um ambiente virtual Python (venv) no diretório de webapp.

        Copia pastas templates/ e static/.

        Instala as dependências do requirements.txt.

    
Agora, vamos criar o manifesto do apko.

nano apko.yaml

contents:
  repositories:
    - ./packages
    - https://dl-cdn.alpinelinux.org/alpine/edge/main
    - https://dl-cdn.alpinelinux.org/alpine/edge/community
  keyring:
    - ./melange.rsa.pub
  packages:
    - giropops-senhas

entrypoint:
  command: /usr/bin/giropops-senhas

archs:
  - x86_64

environment:
  PATH: /usr/bin:/bin


Crie o diretório mkdir packages/

Estrutura:
giropops-senhas/
├── app/                        # Código-fonte da aplicação
│   ├── main.py
│   ├── requirements.txt
│   ├── templates/
│   └── static/
├── melange.yaml         # Receita do pacote .apk
├── apko.yaml            # Receita da imagem
├── melange.key          # Chave pública
├── melange.rsa          # Chave privada
|   melange.rsa.pub      # Chave pública
└── packages/            # Onde o .apk será salvo
├── output/              # Gerado automaticamente com os pacotes
    └── packages/x86_64/





Vamos Buildar a imagem, primeramente, faça login no Docker Hub: *docker login*



Empacotando imagem com Melange via Docker.
```
docker run --rm --privileged \
  -v "${PWD}:/work" \
  -w /work \
  cgr.dev/chainguard/melange \
  build melange.yaml \
  --arch x86_64 \
  --signing-key ./keys/melange.rsa \
  --repository-append ./packages
```

Os campos *INFO wrote packages/x86_64/giropops-senhas-0.1-r0.apk* e 
*INFO writing signed index to packages/x86_64/APKINDEX.tar.gz* indicam que o empacotamento foi realizado com sucesso.

![Title](imagens/melange/buildmelange.png)


Agora possuímos o .apk da aplicação.
Ìndice assinado e o diretório *packages/x86_64/* pronto para o apko.
```
#ls packages/x86_64/
APKINDEX.tar.gz  giropops-senhas-0.1-r0.apk
```



Realizando Build com APKO:

```
docker run --rm \
  -v "${PWD}:/work" \
  -w /work \
  cgr.dev/chainguard/apko \
  build apko.yaml giropops-senhas giropops.tar \
  -k melange.rsa.pub
```

apko.yaml → especifica o que vai na imagem (pacotes, entrypoint etc.)

giropops-senhas → nome lógico da imagem

giropops.tar → imagem gerada como tarball

-k melange.rsa.pub → chave pública usada para verificação de pacotes

Imagem APKO Construída com sucesso.

![Title](imagens/melange/5.png)

Verifique o arquivo gerado: ls -lh giropops.tar
![Title](imagens/melange/4.png)



SUBINDO IMAGEM APKO para o DOCKER HUB.


*docker load < giropops.tar*

![Title](imagens/melange/apko_docker.png)


