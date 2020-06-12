# Ingress Nginx Controller

En AWS o en cualquier otro proveedor, los balanceadores de carga tienen un coste elevado, si para dar acceso a internet a cada servicio del cluster necesitamos desplegar un balanceador que efectue la conexión el coste podria elevarse muchisimo.

Para esto, podemos desplegar una configuracion de NGINX como proxy inverso y enrutador dentro del cluster de manera que todas las conexiones 

https://kubernetes.github.io/ingress-nginx/