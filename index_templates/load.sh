#!/bin/bash

# Itera a través de archivos JSON en el directorio 'component templates'
for file in `ls component_templates/*.json`
do
  # Extrae el nombre del archivo y lo convierte en minúsculas
  #fieldset=`echo $file | cut -d/ -f5 | cut -d. -f1 | tr A-Z a-z`
  
  # Extraer el nombre del archivo y convertirlo en minúsculas
  filename=$(basename "$file")
  filename_without_extension="${filename%.*}"
  
  component_name="${filename%.*}"
  
  #component_name="${fieldset}"

  # Define la ruta de la API de Elasticsearch
  api="_component_template/${component_name}"

  # Muestra en la consola el archivo y la ruta de la API
  echo -e "$file => $api"

  # Realiza una solicitud PUT a la API de Elasticsearch utilizando cURL
  # Comentado para evitar ejecución accidental (descomenta para ejecutar)
  #curl --user "elastic:ntjHM3tMQ2HeqFK4zpil3yVY" -XPUT "https://chinalco.es.us-east-1.aws.found.io/$api" --header "Content-Type: application/json" -d @"$file"
  curl -H "Authorization: ApiKey NDhNMVRvMEJSR2trcmJiaEpxOHk6R1A4b0VhNjVTUW1VdjZ1UXdaMF9PQQ==" -XPUT "https://clinica-internacional-a193c3.es.us-east-1.aws.elastic.cloud/$api" --header "Content-Type: application/json" -d @"$file"

  echo -e "\n"
done
