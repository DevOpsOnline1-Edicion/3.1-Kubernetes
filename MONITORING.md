# Prometheus Grafana

# Monitorizacion de Kubernetes

Monitorear un clúster es absolutamente vital. 
Prometheus y Grafana hacen que sea extremadamente fácil monitorear casi cualquier métrica en su clúster de Kubernetes.


#### Requisitos: 
* Un clúster de Kubernetes existente. 
* binarios de kubectl y helm instalados localmente


## Instale Tiller (servidor Helm) en su clúster

Instalar Tiller es un poco más profundo ya que necesita asegurarlo en clústeres de producción. Con el fin de mantenerlo simple y jugar, lo instalaremos con roles normales de administrador de clúster.

Aasegurarlo para un clúster de producción: 
https://docs.helm.sh/using_helm/#tiller-and-role-based-access-control

Crea una carpeta llamada helm. 
Aquí crearemos todos los recursos de Kubernetes para Tiller. 
Cree un archivo llamado helm / service-account.yml y agregue el siguiente contenido

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
```

Luego aplique y pruebe que la cuenta de servicio existe en el clúster.

```
$ kubectl apply -f helm/service-account.yml


$ kubectl get serviceaccounts -n kube-system
```

### Crear el enlace al rol de cuenta de servicio Para fines de pruebas

> en un cluster de produccion no es recomendable hacer esto tan alegremente por motivos de seguridad.

[Leer mas](https://docs.helm.sh/using_helm/#understanding-the-security-context-of-your-cluster) 

Cree un archivo llamado helm / role-binding.yml en la carpeta helm con el contenido:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```

Aplica y prueba

```
$ kubectl apply -f helm/role-binding.yml
$ kubectl get clusterrolebindings.rbac.authorization.k8s.io
```

#### Deploy Tiller

```
$ helm init --service-account tiller --wait

```

El indicador --wait se asegura de que Tiller esté terminado antes de aplicar los siguientes comandos para comenzar a implementar Prometheus y Grafana.

>NOTA: Helm init has been removed from helm 3.0 :-). You don't need it anymore. There is no more Tiller and the client directories are initialised automatically when you start using helm.


## Instalar Prometheus 

Separaremos nuestros recursos de monitor en un namespace propio para organizar un poco mejor nuestro cluster.


Creamos la carpeta monitoring y en ella añadimos el archivo namespace.yaml

```
kind: Namespace
apiVersion: v1
metadata:
  name: monitoring
```


aplicamos y probamos

```
kubectl get namespaces
```


### Deploy Prometheus

Aquí es donde interviene el poder de Helm y hace la vida mucho más fácil.


Primero tenemos que actualizar nuestro repositorio local de helm charts, helm es un cliente que utiliza repositorios, por defecto deberia incluir alguno tras su instalacion, pero es posible que no, en ese caso podemos agregar e

```
$ helm repo update

# si no hay repo

helm repo add stable https://kubernetes-charts.storage.googleapis.com

# y reintentamos el update

```


Luego, implementamos el chart de Prometheus en el namespace correspondiente ( si no  lo hara en default )

```
helm install prometheus stable/prometheus --namespace monitoring
```


Esto desplegará Prometheus en su clúster en el namespace indicado y marcará el lanzamiento con el nombre prometheus.

Prometheus ahora realiza "scraping" en el clúster junto con el exportador de nodos y recopila métricas de los nodos.

Podemos confirmar comprobando que los pods se están ejecutando:

```
$ kubectl get pods -n monitoring

```

## Instalar Grafana

Al implementar grafana, debemos configurarlo para leer las métricas de las fuentes de datos correctas, grafana soporta muchos origenes de datos entre ellos Prometheus.

http://docs.grafana.org/administration/provisioning/#datasources

Kubernetes no tiene nada que ver con la importación de datos. Kubernetes simplemente organiza la inyección de estos archivos yaml.

Cuando se despliegue el Helm Chart de Grafana, buscará cualquier mapa de configuración que contenga una etiqueta grafana_datasource.

### Creamos el ConfigMap del DataSource Prometheus

En la carpeta de monitoring, cree una subcarpeta llamada grafana.

Aquí es donde almacenaremos nuestras configuraciones para la implementación de grafana.

Cree un archivo llamado tracking / grafana / config.yml con el contenido:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-grafana-datasource
  namespace: monitoring
  labels:
    grafana_datasource: '1'
data:
  datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      orgId: 1
      url: http://prometheus-server.monitoring.svc.cluster.local
```

Aquí es donde agregamos la etiqueta grafana_datasource que le indicará al aprovisionador de grafana que esta es una fuente de datos que debe inyectar.

```
labels:
    grafana_datasource: '1'

```

Aplicamos y comprobamos

```
$ kubectl apply -f monitoring/grafana/config.yml
$ kubectl get configmaps -n monitoring
```

### Anular el valor de grafana

Cuando se implementa Grafana y se ejecuta el aprovisionador, el aprovisionador de origen de datos se desactiva. Necesitamos activarlo para que busque nuestros mapas de configuración.

Necesitamos crear nuestro propio archivo values.yml para anular el valor de búsqueda de fuentes de datos, por lo que cuando se implemente Grafana, buscará nuestra definición de datasource.yml y la inyectará.

Cree un archivo llamado tracking / grafana / values.yml con el contenido:

```
sidecar:
  datasources:
    enabled: true
    label: grafana_datasource
```

Esto inyectará un sidecar que cargará todas las fuentes de datos en Grafana cuando se aprovisione.

Ahora podemos implementar Grafana con el archivo anulado values.yml y se importará nuestra fuente de datos.

```
helm install grafana stable/grafana -f monitoring/grafana/values.yaml --namespace monitoring
```

comprobamos

```
kubectl get pods -n monitoring
```

### Obtenga la contraseña de Grafana 
Grafana  se implementa con una contraseña. ¿Pero cuál es la contraseña?

```
kubectl get secret \
    --namespace monitoring grafana \
    -o jsonpath="{.data.admin-password}" \
    | base64 --decode ; echo
```

Esto volcará la contraseña de Grafana. El nombre de usuario es admin.

Aunque esto podemos consultarlo tambien a traves del dashboard.


### Accediendo a Grafana

Podemos acceder mediante port forward a grafana, o exponiendo a internet el servicio mediante loadbalancer o ingress.

```
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=grafana,release=grafana" -o jsonpath="{.items[0].metadata.name}")
$ kubectl --namespace monitoring port-forward $POD_NAME 3000

```

kubectl --namespace monitoring port-forward service/grafana 3000:80

http://localhost:3000 



Vamos a añadir algunos dashboards editando el values ( hay muchos metodos para hacer esto )

```
sidecar:
  datasources:
    enabled: true
    label: grafana_datasource
  dashboards:
    enabled: true
    label: grafana_dashboard
```

helm upgrade --install grafana stable/grafana -f monitoring/grafana/values.yaml --namespace monitoring