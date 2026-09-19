FROM nginx:alpine

# Remove a config padrão do nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia nossa config customizada
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copia o build web do Flutter
COPY build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
