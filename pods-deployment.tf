
//Kubernetes Provider

provider "kubernetes" {
  //By Default works on Current Context
}

//Creating PVC for nextcloud Pod

resource "kubernetes_persistent_volume_claim" "nextcloud-pvc" {
  metadata {
    name   = "nextcloud-pvc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}


//Creating PVC for mariadb Pod

resource "kubernetes_persistent_volume_claim" "mariadb-pvc" {
  metadata {
    name   = "mariadb-pvc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

//Creating Deployment for mariadb Pod

resource "kubernetes_deployment" "mariadb-deployment" {
  metadata {
    name   = "mariadb-deployment"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        pod     = "mariadb"
        env     = "Production"
        Country = "India" 
      }
    }

    template {
      metadata {
        labels = {
          pod     = "mariadb"
          env     = "Production"
          Country = "India" 
        }
      }

      spec {
        volume {
          name = "mariadb-volume"
          persistent_volume_claim { 
            claim_name = kubernetes_persistent_volume_claim.mariadb-pvc.metadata.0.name
          }
        }

        container {
          image = "mariadb:latest"
          name  = "mariadb-container"

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "root"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "mariadb"
          }
          env {
            name  = "MYSQL_USER"
            value = "user"
          }
          env{
            name  = "MYSQL_PASSWORD"
            value = "its-rahul"
          }

          volume_mount {
              name       = "mariadb-volume"
              mount_path = "/var/lib/mysql"
          }

          port {
            container_port =80
          }
        }
      }
    }
  }
}

//Creating Deployment for nextcloud

resource "kubernetes_deployment" "nextcloud-deployment" {
  metadata {
    name   = "nextcloud-deployment"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }
  depends_on = [
    kubernetes_deployment.mariadb-deployment, 
    kubernetes_service.mariadbService
  ]

  spec {
    replicas = 1
    selector {
      match_labels = {
        pod     = "nextcloud"
        env     = "Production"
        Country = "India" 
        
      }
    }

    template {
      metadata {
        labels = {
          pod     = "nextcloud"
          env     = "Production"
          Country = "India"  
        }
      }

      spec {
        volume {
          name = "nextcloud-volume"
          persistent_volume_claim { 
            claim_name = kubernetes_persistent_volume_claim.nextcloud-pvc.metadata.0.name
          }
        }

        container {
          image = "nextcloud:latest"
          name  = "nextcloud-container"

          env {
            name  = "NEXTCLOUD_DB_HOST"
            value = kubernetes_service.mariadbService.metadata.0.name
          }
          env {
            name  = "NEXTCLOUD_DB_USER"
            value = "user"
          }
          env {
            name  = "NEXTCLOUD_DB_PASSWORD"
            value = "its-rahul"
          }
          env{
            name  = "NEXTCLOUD_DB_NAME"
            value = "nextcloud-db"
          }
          env{
            name  = "WORDPRESS_TABLE_PREFIX"
            value = "nextcloud_"
          }

          volume_mount {
              name       = "nextcloud-volume"
              mount_path = "/var/www/html/"
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}



//Creating LoadBalancer Service for nextcloud Pods

resource "kubernetes_service" "nextcloudService" {
  metadata {
    name   = "nextcloud-service"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }  

  depends_on = [
    kubernetes_deployment.nextcloud-deployment
  ]

  spec {
    type     = "LoadBalancer"
    selector = {
      pod = "nextcloud"
    }

    port {
      name = "nextcloud-port"
      port = 80
    }
  }
}

//Creating ClusterIP service for mariadb Pods

resource "kubernetes_service" "mariadbService" {
  metadata {
    name   = "mariadb-service"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }  
  depends_on = [
    kubernetes_deployment.mariadb-deployment
  ]

  spec {
    selector = {
      pod = "mariadb"
    }
  
    cluster_ip = "None"
    port {
      name = "mariadb-port"
      port = 3306
    }
  }
}

//Wait For LoadBalancer to Register IPs

resource "time_sleep" "wait_120_seconds" {
  create_duration = "120s"
  depends_on = [kubernetes_service.nextcloudService]  
}

//Open nextcloud

resource "null_resource" "open_nextcloud" {
  provisioner "local-exec" {
    command = "start chrome ${kubernetes_service.nextcloudService.load_balancer_ingress.0.hostname}"
  }

  depends_on = [
    time_sleep.wait_120_seconds
  ]
}
