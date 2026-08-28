# ==========================================
# BaknusChat Web Dockerfile (Nginx Alpine)
# ==========================================
FROM nginx:alpine

# Hapus konfigurasi default Nginx
RUN rm -rf /etc/nginx/conf.d/default.conf

# Salin konfigurasi Nginx kustom untuk Flutter Web (SPA)
COPY nginx.conf /etc/nginx/conf.d/baknuschat.conf

# Salin seluruh berkas hasil build Flutter Web ke direktori Nginx
COPY build/web /usr/share/nginx/html

# Expose port 80 untuk lalu lintas HTTP Web
EXPOSE 80

# Jalankan Nginx di foreground
CMD ["nginx", "-g", "daemon off;"]
